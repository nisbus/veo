FROM erlang:22.2.2
RUN apt-get update
RUN apt-get install -y \
	apt-transport-https \
	ca-certificates \
	curl \
	gnupg-agent \
	software-properties-common \
	supervisor \
	wget \
	net-tools \
	dnsutils
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian \
	$(lsb_release -cs) \
	stable"
RUN apt-get update
RUN apt-get install -y docker-ce docker-ce-cli containerd.io
RUN wget https://s3.amazonaws.com/rebar3/rebar3 && chmod +x rebar3
RUN mkdir -p /etc/docker
RUN echo "{\"storage-driver\": \"vfs\"}" > /etc/docker/daemon.json
COPY ./rebar.config /.
RUN rebar3 get-deps
RUN rebar3 compile
COPY ./ /.
RUN rebar3 release
RUN sed -i 's|CODE_LOADING_MODE="${CODE_LOADING_MODE:-embedded}"|CODE_LOADING_MODE=""|g' _build/default/rel/veo/bin/veo
RUN mkdir -p /var/log/supervisor
COPY ./supervisor.conf /etc/supervisor/conf.d/supervisor-local.conf
RUN mkdir -p /opt/veo/dns_data
RUN mkdir -p /etc/veo
RUN echo "[]" > /etc/veo/zones.json
ENTRYPOINT ["./entrypoint.sh"]
