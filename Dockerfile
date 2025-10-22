FROM ruby:3.2-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssh-client iproute2 procps && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY script.rb /app/script.rb
RUN chmod +x /app/script.rb
ENTRYPOINT ["ruby","/app/script.rb"]
