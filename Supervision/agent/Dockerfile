FROM ruby:3.2-slim

# Installation des outils de compilation + dépendances système
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    procps \
    iproute2 \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Installation des gems Ruby (avec rackup)
RUN gem install sinatra rackup puma --no-document

# Configuration du répertoire de travail
WORKDIR /app

# Copie du script
COPY script.rb /app/script.rb
RUN chmod +x /app/script.rb

# Exposition du port
EXPOSE 4567

# Démarrage en mode agent
CMD ["ruby", "/app/script.rb", "--agent"]
