FROM ruby:3.0-slim

WORKDIR /app

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    build-essential \
    sysstat \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Installation de TOUTES les gems nécessaires
RUN gem install sinatra sinatra-contrib json rackup puma webrick

# Copie du script
COPY script.rb .

# Exposition du port
EXPOSE 4567

# Démarrage du script en mode agent
CMD ["ruby", "script.rb", "--agent"]
