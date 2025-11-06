#!/bin/bash
set -e

echo "=== DACS Supervision - Auto Setup ==="

# Détection utilisateur & IP
CURRENT_USER=$(whoami)
HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n1)

echo "Utilisateur : $CURRENT_USER"
echo "IP hôte    : $HOST_IP"

# Chemin clé SSH
SSH_KEY="$HOME/.ssh/id_audit"

# Génère clé si absente
if [ ! -f "$SSH_KEY" ]; then
  echo "Clé SSH absente → génération automatique..."
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q
  echo "Clé générée : $SSH_KEY"
else
  echo "Clé SSH trouvée : $SSH_KEY"
fi

# Copie clé sur la machine hôte (même IP)
echo "Ajout de la clé SSH sur $CURRENT_USER@$HOST_IP..."
if ! ssh-copy-id -i "$SSH_KEY.pub" "$CURRENT_USER@$HOST_IP" >/dev/null 2>&1; then
  echo "Attention : ssh-copy-id a échoué (déjà présent ou mot de passe requis)."
  echo "   → Vérifiez avec : ssh $CURRENT_USER@$HOST_IP"
fi

# Génère .env avec valeurs dynamiques
cat > Supervision/.env << EOF
REMOTE_HOST_AGENT1=$HOST_IP
REMOTE_HOST_AGENT2=$HOST_IP
REMOTE_USER=$CURRENT_USER
SSH_KEY_PATH=/root/.ssh/id_audit
HOST_SSH_KEY=$SSH_KEY
EOF

echo ".env généré dans Supervision/"

# Nettoyage propre + démarrage
cd Supervision
echo "Arrêt des conteneurs existants..."
docker compose down --remove-orphans -v 2>/dev/null || true

echo "Construction & démarrage de la stack..."
docker compose up -d --build

# Attente que les agents soient prêts
echo "Attente du démarrage des agents..."
sleep 8

# Vérification rapide des endpoints
if curl -s http://localhost:4567/metrics | grep -q "load_average"; then
  echo "Agent1 OK (métriques accessibles)"
else
  echo "Agent1 KO : pas de réponse sur /metrics"
fi

if curl -s http://localhost:4568/metrics | grep -q "load_average"; then
  echo "Agent2 OK (métriques accessibles)"
else
  echo "Agent2 KO : pas de réponse sur /metrics"
fi

echo ""
echo "TOUT EST PRÊT !"
echo "   Prometheus : http://localhost:9090"
echo "   Grafana    : http://localhost:3000 (admin/admin)"
echo "   Agent1     : http://localhost:4567/metrics"
echo "   Agent2     : http://localhost:4568/metrics"
echo ""
echo "Astuce : Pour relancer → ./start.sh"