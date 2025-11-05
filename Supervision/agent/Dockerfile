FROM ruby:3.0-slim

WORKDIR /app

# Installation des dépendances systèmes nécessaires
RUN apt-get update && apt-get install -y \
    build-essential \
    sysstat \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Installation des gems nécessaires
RUN gem install sinatra sinatra-contrib json

# Copie du script dans le conteneur
COPY script.rb .

# Exposition du port de l'agent
EXPOSE 4567

# Démarrage du script en mode agent
CMD ["ruby", "script.rb", "--agent"]
