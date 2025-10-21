
FROM ruby:3.3-slim
RUN apt-get update && apt-get install -y procps net-tools iproute2 lsb-release && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY script.rb .
CMD ["ruby", "/app/script.rb"]