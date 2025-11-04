FROM ruby:3.2
RUN apt-get update && apt-get install -y iproute2 iputils-ping net-tools && \
    gem install sinatra json rackup puma
WORKDIR /app
COPY script.rb /app/script.rb
EXPOSE 4567
CMD ["ruby", "script.rb", "--agent"]

