#!/bin/bash
set -e

echo "Détection de l'utilisateur courant..."
CURRENT_USER=$(whoami)
echo "Utilisateur détecté : $CURRENT_USER"

echo "Détection de l'IP de la machine hôte..."
HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n1)

if [ -z "$HOST_IP" ]; then
  echo "ERREUR : Impossible de détecter l'IP hôte"
  exit 1
fi

echo "IP hôte détectée : $HOST_IP"

# Génère .env dans Supervision/
cat > Supervision/.env << EOF
REMOTE_HOST_AGENT1=$HOST_IP
REMOTE_HOST_AGENT2=$HOST_IP
REMOTE_USER=$CURRENT_USER
SSH_KEY_PATH=/home/$CURRENT_USER/.ssh/id_audit
EOF

echo "Fichier Supervision/.env créé"

echo "Démarrage de la stack..."
cd Supervision
docker compose up -d --build

echo ""
echo "Stack lancée !"
echo "   Prometheus : http://localhost:9090"
echo "   Grafana    : http://localhost:3000 (admin/admin)"
echo "   Agent1     : http://localhost:4567/metrics"
echo "   Agent2     : http://localhost:4568/metrics"