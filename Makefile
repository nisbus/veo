default:
	cd apps/veo/priv/veo-ui & rebar3 shell

run:
	docker run -d --privileged -e NAME=veo -e COOKIE=cookie veo:latest

stop_dns:
	sudo systemctl stop systemd-resolved.service
	sudo systemctl stop dnsmasq.service

start_dns:
	sudo systemctl start systemd-resolved.service
	sudo systemctl start dnsmasq.service

start_docker:
	docker build --cache-from veo:latest -t veo .
	docker run -d --rm --name veo --privileged -v /var/run/docker.sock:/var/run/docker.sock --hostname=veo -e NAME=veo -e COOKIE=cookie veo:latest

start_local: update build stop_dns
	sudo rebar3 shell --sname veo

shell:
	rm -rf /opt/veo/dns_data
	sudo rebar3 shell --sname veo

update:
	rebar3 upgrade

build:
	rebar3 compile


release:
	rebar3 release
	sed -i 's|CODE_LOADING_MODE="${CODE_LOADING_MODE:-embedded}"|CODE_LOADING_MODE=""|g' _build/default/rel/veo/bin/veo
