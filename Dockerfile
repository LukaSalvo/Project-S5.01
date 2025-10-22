FROM ruby:3.2-slim
RUN apt-get update && apt-get install -y lsb-release iproute2 procps net-tools && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY script.rb /app/audit.rb
ENTRYPOINT ["ruby", "/app/audit.rb"]
