%%%-------------------------------------------------------------------
%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2019, nisbus
%%% @doc
%%% DNS management for containers
%%% 
%%% @end
%%% Created :  19 Jun 2020 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(dns_registry).
-export([add_service/4, remove_records/3]).
-include("../../../_build/default/lib/erldns/include/erldns.hrl").
-include("../include/container.hrl").


%%-------------------------------------------------------------------
%% @doc
%% Adds a service to the DNS
%% If the service already exists it will add the A and SRV records
%% to the existing service.
%% @end
%%-------------------------------------------------------------------
-spec(add_service(Name::string()|binary(), SHA::binary, IP::tuple(), PortMaps::[#port{}]) -> ok | {error, term()}).    
add_service(Name, SHA, IP, PortMaps) ->
    SRV_Records = get_srv_records(PortMaps, Name, IP),
    BName = name_to_binary(Name),
    NSName = namespace_name(Name),
    AdminName = admin_name(Name),

    case get_zone(Name) of
	[] ->
	    Zone = {BName, SHA, [
				 #dns_rr{
				    name=BName,
				    type=?DNS_TYPE_SOA,
				    ttl=3600,
				    data=#dns_rrdata_soa{
					    mname=NSName,
					    rname=AdminName,
					    serial=2013022001,
					    refresh=86400,
					    retry=7200,
					    expire=604800,
					    minimum=300
					   }
				   },
				 #dns_rr{
				    name=BName,
				    type=?DNS_TYPE_A,
				    ttl=3600,
				    data = #dns_rrdata_a{ip=IP}
				   },
				 #dns_rr{
				    name=BName,
				    type=?DNS_TYPE_NS,
				    ttl=3600,
				    data = #dns_rrdata_ns{
					      dname=NSName
					     }
				   }
				]++SRV_Records},
	    lager:debug("Adding ~p to DNS~n", [Name]),
	    erldns_zone_cache:put_zone(Zone);
	Records ->
	    NewA = #dns_rr{
		      name=BName,
		      type=?DNS_TYPE_A,
		      ttl=3600,
		      data = #dns_rrdata_a{ip=IP}
		     },
	    Added = Records ++ [NewA] ++ SRV_Records,
	    Zone = {BName, SHA, Added},
	    erldns_zone_cache:put_zone(Zone)
    end.
	    
%%-------------------------------------------------------------------
%% @doc
%% Removes a service to the DNS
%% Removes the A records matching this services IP
%% Removes SRV records if the service has randomly assigned ports.
%% If after removing there are no A records for the service left,
%% it will be completely removed.
%% @end
%%-------------------------------------------------------------------
-spec(remove_records(Name::string()|binary(), PortMaps::[#port{}], IP::tuple()) -> ok | {error, term()}).        
remove_records(Name, PortMaps, IP) ->
    BName = name_to_binary(Name),
    case erldns_zone_cache:get_zone_records(BName) of
	[] ->
	    void;
	Records ->
	    {ok, {zone, _, SHA, _, _, _, _, _, _}} = erldns_zone_cache:get_zone(BName),
	    Filtered = lists:filter(fun(#dns_rr{type=Type, data=Data}) -> 
					    case Type of
						?DNS_TYPE_A ->
						    case Data#dns_rrdata_a.ip of
							IP ->
							    false;
							_ ->
							    true
						    end;
						?DNS_TYPE_SRV ->
						    Port = Data#dns_rrdata_srv.port,
						    Found = lists:any(fun(#port{random=Random, host_port=HP}) ->
									      case Random of
										  true ->									
										      HP =:= Port;
										  false ->
										      false
									      end 
								      end, PortMaps),
						    case Found of
							true ->
							    false;
							_ -> true
						    end;						
						_ ->
						    true
					    end
				    end, Records),	    
	    ARecords = lists:any(fun(#dns_rr{type=Type}) ->
					 case Type of
					     ?DNS_TYPE_A ->
						 true;
					     _ ->
						 false
					 end
					 end, Filtered),
	    case ARecords of
		true ->						 
		    erldns_zone_cache:put_zone({BName, SHA, Filtered}),
		    lager:debug("Updated/removed DNS records for ~p~n", [Name]);
		false ->
		    erldns_zone_cache:delete_zone(BName),
		    lager:debug("Removed ~p from DNS~n", [Name])		    
	    end
    end.


				     
						     
					 

namespace_name(Name) when is_list(Name) ->
    list_to_binary("ns1."++Name++".veo");
namespace_name(Name) when is_binary(Name) ->
    namespace_name(binary_to_list(Name)).

admin_name(Name) when is_list(Name) ->
    list_to_binary("admin."++Name++".veo");
admin_name(Name) when is_binary(Name) ->
    admin_name(binary_to_list(Name)).

get_zone(Name) ->
    BName = name_to_binary(Name),
    erldns_zone_cache:get_zone_records(BName).

get_srv_records(PortMaps, Name, IP) ->
    lists:flatten(lists:map(fun(#port{host_port=Port, name=PortName, protocol=Protocol}) ->
				    SRVName = name_to_srv_name(PortName, Name, Protocol),
				    Target = port_target_name(PortName, Name),
				    [#dns_rr{
					name=SRVName,
					type=?DNS_TYPE_SRV,
					ttl=3600,
					data=#dns_rrdata_srv{port=Port, 
							     priority=0, 
							     target=Target,
							     weight=100
							    }
				       },
				     #dns_rr{
					name=Target,
					type=?DNS_TYPE_A,
					ttl=3600,
					data=#dns_rrdata_a{ip=IP}}]
	      end, PortMaps)).


name_to_srv_name(PortName, Name, Protocol) when is_list(PortName) and is_list(Name) ->    
    list_to_binary("_"++PortName++"._"++atom_to_list(Protocol)++"."++Name++".veo");
name_to_srv_name(PortName, Name, Protocol) when is_binary(PortName) ->
    name_to_srv_name(binary_to_list(PortName), Name, Protocol);
name_to_srv_name(PortName, Name, Protocol) when is_binary(Name) ->
    name_to_srv_name(PortName, binary_to_list(Name), Protocol).

port_target_name(PortName, Name) when is_list(PortName) and is_list(Name) ->
    list_to_binary(PortName++"."++Name++".veo");
port_target_name(PortName, Name) when is_binary(PortName) ->
    port_target_name(binary_to_list(PortName), Name);
port_target_name(PortName, Name) when is_binary(Name) ->
    port_target_name(PortName, binary_to_list(Name)).

name_to_binary(Name) when is_list(Name) ->
    list_to_binary(Name++".veo");
name_to_binary(Name) when is_binary(Name) ->
    name_to_binary(binary_to_list(Name)).
