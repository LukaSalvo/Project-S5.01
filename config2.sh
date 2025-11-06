#!/bin/bash

echo "=== Configuration SSH pour DACS AUDIT ==="
echo ""

# Variables
SSH_KEY="$HOME/.ssh/id_audit"
REMOTE_USER="salvo4u"
REMOTE_HOST="100.64.85.5"

# 1. Générer la clé SSH
if [ ! -f "$SSH_KEY" ]; then
    echo " Génération de la clé SSH..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N ""
    echo " Clé générée"
else
    echo " Clé SSH déjà existante"
fi

# 2. Ajouter la clé dans authorized_keys
echo ""
echo " Configuration de authorized_keys..."
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
cat "${SSH_KEY}.pub" >> ~/.ssh/authorized_keys

# 3. Permissions
echo " Configuration des permissions..."
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 "$SSH_KEY"
chmod 644 "${SSH_KEY}.pub"
echo " Permissions configurées"

# 4. Test SSH
echo ""
echo " Test de connexion SSH..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "echo 'SSH OK'" 2>/dev/null | grep -q "SSH OK"; then
    echo " Connexion SSH fonctionnelle"
else
    echo " Erreur de connexion SSH"
    echo "Vérifiez que le service SSH est actif:"
    echo "  sudo systemctl status ssh"
    exit 1
fi

# 5. Afficher le résumé
echo ""
echo "=== Configuration terminée ==="
echo "Utilisateur : $REMOTE_USER"
echo "IP          : $REMOTE_HOST"
echo "Clé SSH     : $SSH_KEY"
echo ""
echo "Vous pouvez maintenant :"
echo "1. cd Supervision/"
echo "2. docker-compose build"
echo "3. docker-compose up -d"
echo "4. curl http://localhost:4567/metrics"