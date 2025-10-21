FROM ruby:3.2-alpine

RUN apk update && apk add --no-cache \
    build-base \
    git \
    curl \
    iproute2 \
    procps \
    util-linux \
    net-tools \
    openssh-client \
    openssh-server \
    && rm -rf /var/cache/apk/*

WORKDIR /app

COPY script.rb /app/
COPY ssh-keys/ /root/.ssh/

RUN chmod 600 /root/.ssh/id_rsa \
    && chmod 644 /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys \
    && chmod +x /app/script.rb \
    && echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

# Variable pour détecter si on audit l'hôte
ENV HOST_ROOT=/

ENTRYPOINT ["ruby", "/app/script.rb"]
