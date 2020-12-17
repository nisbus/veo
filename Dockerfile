FROM erlang:23.2
RUN apt-get update
RUN apt-get install -y \
	curl \
	gnupg-agent \
	software-properties-common \
	supervisor \
	wget \
	net-tools \
	dnsutils \
	emacs \
	nano

###############ONLY FOR RUNNING AS DOCKER IN DOCKER#######################
##	apt-transport-https \
##	ca-certificates \
#RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
#RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian \
#	$(lsb_release -cs) \
#	stable"
#RUN apt-get install -y docker-ce docker-ce-cli containerd.io nano
#RUN mkdir -p /etc/docker
#RUN echo "{\n\t\"storage-driver\": \"vfs\",\n\t\"insecure-registries\":[\"192.168.1.75:5000\"]\n}" > /etc/docker/daemon.json

RUN wget https://s3.amazonaws.com/rebar3/rebar3 && chmod +x rebar3
COPY ./rebar.config /.
RUN rebar3 get-deps
COPY ./ /.
RUN rebar3 compile
RUN rebar3 release
RUN sed -i 's|CODE_LOADING_MODE="${CODE_LOADING_MODE:-embedded}"|CODE_LOADING_MODE=""|g' _build/default/rel/veo/bin/veo
RUN mkdir -p /opt/veo/dns_data
RUN mkdir -p /etc/veo
RUN echo "[]" > /etc/veo/zones.json
RUN ln -s /_build/default/rel/veo/bin/veo .
#############################ONLY FOR DIND#############################
#RUN mkdir -p /var/log/supervisor
#COPY ./supervisor.conf /etc/supervisor/conf.d/supervisor-local.conf
#ENTRYPOINT ["./entrypoint.sh"]
ENTRYPOINT ["veo", "start"]
