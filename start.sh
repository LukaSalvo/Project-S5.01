#!/bin/bash
set -e

echo "=== DACS Supervision - Auto Setup ==="

CURRENT_USER=$(whoami)
HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n1)

echo "Utilisateur : $CURRENT_USER"
echo "IP hôte    : $HOST_IP"

SSH_KEY="$HOME/.ssh/id_audit"

# Génère clé si absente
[ ! -f "$SSH_KEY" ] && {
  echo "Génération clé SSH..."
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q
}

# Copie clé sur la machine hôte
echo "Copie clé SSH sur $CURRENT_USER@$HOST_IP..."
ssh-copy-id -i "$SSH_KEY.pub" "$CURRENT_USER@$HOST_IP" >/dev/null 2>&1 || true

# Génère .env
cat > Supervision/.env << EOF
REMOTE_HOST_AGENT1=$HOST_IP
REMOTE_HOST_AGENT2=$HOST_IP
REMOTE_USER=$CURRENT_USER
SSH_KEY_PATH=/root/.ssh/id_audit
HOST_SSH_KEY=$SSH_KEY
EOF

# Démarre
cd Supervision
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d --build

echo ""
echo "PRÊT !"
echo "   http://localhost:9090 → Prometheus"
echo "   http://localhost:3000 → Grafana (admin/admin)"