#Dockerfile de l'agent 


FROM ruby:3.2-slim

RUN apt-get update && apt-get install -y --no-install-recommends lsb-release procps iproute2 net-tools systemctl openssh-client && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY script.rb agent.rb /app/
RUN chmod +x /app/script.rb /app/agent.rb