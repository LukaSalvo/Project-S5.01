FROM ruby:3.2-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    lsb-release procps iproute2 net-tools curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ../agent.rb /app/
RUN gem install webrick json && chmod +x /app/agent.rb

EXPOSE 9091

CMD ["ruby", "/app/agent.rb"]
