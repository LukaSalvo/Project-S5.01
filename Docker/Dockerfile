FROM ruby:3.2-slim
RUN apt-get update && \
    apt-get install -y iproute2 net-tools procps systemd sudo && \
    rm -rf /var/lib/apt/lists/* 
WORKDIR /app
COPY ../script.rb .
RUN chmod +x script.rb
ENTRYPOINT ["./script.rb"]