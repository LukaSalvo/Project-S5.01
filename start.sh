#!/bin/bash
set -e

echo "=== Configuration automatique DACS Supervision ==="

# 1. Détection utilisateur + IP
CURRENT_USER=$(whoami)
echo "Utilisateur détecté : $CURRENT_USER"

HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n1)
if [ -z "$HOST_IP" ]; then
  echo "ERREUR : Impossible de détecter l'IP hôte"
  exit 1
fi
echo "IP hôte détectée : $HOST_IP"

# 2. Chemin clé SSH
SSH_KEY="$HOME/.ssh/id_audit"

# 3. Génère clé si absente
if [ ! -f "$SSH_KEY" ]; then
  echo "Clé SSH manquante → génération automatique..."
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q
  echo "Clé générée : $SSH_KEY"
else
  echo "Clé SSH existante : $SSH_KEY"
fi

# 4. Ajoute clé sur la machine distante (même IP = hôte)
echo "Ajout de la clé SSH sur $CURRENT_USER@$HOST_IP..."
ssh-copy-id -i "$SSH_KEY.pub" "$CURRENT_USER@$HOST_IP" || {
  echo "Échec ssh-copy-id. Essaie manuellement :"
  echo "   ssh-copy-id $CURRENT_USER@$HOST_IP"
  exit 1
}

# 5. Crée .env
cat > Supervision/.env << EOF
REMOTE_HOST_AGENT1=$HOST_IP
REMOTE_HOST_AGENT2=$HOST_IP
REMOTE_USER=$CURRENT_USER
SSH_KEY_PATH=/root/.ssh/id_audit
HOST_SSH_KEY=$SSH_KEY
EOF

echo ".env généré dans Supervision/"

# 6. Lance la stack
cd Supervision
echo "Démarrage de la stack..."
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d --build

echo ""
echo "=== TOUT EST PRÊT ! ==="
echo "   Prometheus : http://localhost:9090"
echo "   Grafana    : http://localhost:3000 (admin/admin)"
echo "   Agent1     : http://localhost:4567/metrics"
echo "   Agent2     : http://localhost:4568/metrics"
echo ""
echo "Tout est automatisé. Partage ce script avec n’importe qui !"