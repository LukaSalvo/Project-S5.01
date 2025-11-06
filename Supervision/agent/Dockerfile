FROM ruby:3.0-slim
WORKDIR /app
RUN apt-get update && apt-get install -y \
    build-essential \
    sysstat \
    procps \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*
RUN gem install sinatra sinatra-contrib json rackup puma webrick
COPY script.rb .
EXPOSE 4567
CMD ["ruby", "script.rb", "--agent"]