
default:
	cd apps/veo/priv/veo-ui && ng serve & rebar3 shell

run:
	docker run -d --privileged -e NAME=uno -e COOKIE=cookie scheduler:latest

start: update build
	rebar3 shell

update:
	rebar3 upgrade

build:
	rebar3 compile

release:
	rebar3 release
	sed -i 's|CODE_LOADING_MODE="${CODE_LOADING_MODE:-embedded}"|CODE_LOADING_MODE=""|g' _build/default/rel/veo/bin/veo

docker: 
	docker build -t scheduler .

multiple: docker
	docker kill uno || true
	docker kill dos || true
	docker network rm veo || true
	docker network create veo
	docker run -d --rm --name uno --net veo --privileged -e NAME=uno --hostname=uno -e COOKIE=cookie scheduler:latest
	sleep 20
	docker run -d --rm --name=dos --net veo --hostname=dos -e NAME=dos -e COOKIE=cookie --privileged scheduler:latest

three: docker
	docker kill uno || true
	docker kill dos || true
	docker network rm volta || true
	docker network create veo
	docker run -d --rm --name uno --net veo --privileged -e NAME=uno --hostname=uno -e COOKIE=cookie scheduler:latest
	sleep 20
	docker run -d --rm --name=dos --net veo --hostname=dos -e NAME=dos -e COOKIE=cookie --privileged scheduler:latest
	docker run -d --rm --name=tres --net veo --hostname=tres -e NAME=tres -e COOKIE=cookie --privileged scheduler:latest
