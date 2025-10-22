#!/bin/bash
# =============================================================
#  DACS AUDIT - Script Client SSH Docker (mode local)
#  Auteurs : Amin Belalia, Luka Salvo, Léo Candido Della Mora
# =============================================================

set -euo pipefail

# Récupération automatique de l'utilisateur et de l'adresse IP locale
USER_NAME=$(whoami)
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

if [ -z "$LOCAL_IP" ]; then
  echo "Erreur : impossible de récupérer l'adresse IP locale."
  exit 1
fi

echo "Utilisateur détecté : $USER_NAME"
echo "Adresse IP locale : $LOCAL_IP"

# Vérification de Docker
if ! command -v docker &> /dev/null; then
  echo "Docker n'est pas installé. Veuillez l'installer avant de continuer."
  exit 1
fi

# Vérification ou génération de la clé SSH dédiée à l'audit
if [ ! -f "${HOME}/.ssh/id_audit" ]; then
  echo "Clé SSH d'audit introuvable. Génération de ~/.ssh/id_audit (sans passphrase)..."
  mkdir -p "${HOME}/.ssh"
  ssh-keygen -t rsa -b 4096 -f "${HOME}/.ssh/id_audit" -N "" >/dev/null
else
  echo "Clé SSH trouvée : ~/.ssh/id_audit"
fi

# Assurer que la clé publique est dans authorized_keys pour autoriser la connexion locale
AUTH_FILE="${HOME}/.ssh/authorized_keys"
PUBKEY_CONTENT=$(cat "${HOME}/.ssh/id_audit.pub")

mkdir -p "${HOME}/.ssh"
touch "${AUTH_FILE}"
chmod 700 "${HOME}/.ssh"
chmod 600 "${AUTH_FILE}"

if ! grep -qxF "${PUBKEY_CONTENT}" "${AUTH_FILE}"; then
  echo "Ajout de la clé publique id_audit à ${AUTH_FILE} pour autoriser les connexions locales."
  cat "${HOME}/.ssh/id_audit.pub" >> "${AUTH_FILE}"
else
  echo "La clé publique id_audit est déjà présente dans ${AUTH_FILE}."
fi

# Vérification simple : SSH localhost (test rapide, silencieux)
if ssh -o BatchMode=yes -o ConnectTimeout=3 -i "${HOME}/.ssh/id_audit" "${USER_NAME}@${LOCAL_IP}" 'echo OK' 2>/dev/null | grep -q OK; then
  echo "Connexion SSH locale testée avec succès (via clé id_audit)."
else
  echo "Remarque : la connexion SSH locale via clé id_audit a échoué au test non interactif."
  echo "Cela peut être normal si le serveur SSH n'écoute pas l'IP locale ou si le service SSH est configuré différemment."
  echo "Le conteneur devrait cependant réussir si --network host est utilisé."
fi

# Construire l'image Docker dacs-audit si absente
if [[ "$(docker images -q dacs-audit:latest 2> /dev/null)" == "" ]]; then
  echo "Construction de l'image Docker dacs-audit:latest..."
  docker build -t dacs-audit:latest .
else
  echo "Image Docker dacs-audit:latest déjà disponible."
fi

# Choix du mode d’audit (terminal ou JSON)
echo
echo "Choisissez le mode d’audit :"
echo "1) Affichage direct dans le terminal"
echo "2) Export JSON (audit_distant.json)"
read -r -p "Sélection (1 ou 2) : " CHOICE

if [ "$CHOICE" = "1" ]; then
  echo "Lancement de l’audit local (affichage terminal) en utilisant ${LOCAL_IP}..."
  docker run --rm -it \
    --network host \
    -v "${HOME}/.ssh/id_audit:/root/.ssh/id_audit:ro" \
    dacs-audit:latest \
      --remote-host "${LOCAL_IP}" \
      --remote-user "${USER_NAME}" \
      --key /root/.ssh/id_audit
else
  echo "Lancement de l’audit local (export JSON) en utilisant ${LOCAL_IP}..."
  docker run --rm -it \
    --network host \
    -v "${HOME}/.ssh/id_audit:/root/.ssh/id_audit:ro" \
    -v "$(pwd):/app" \
    dacs-audit:latest \
      --remote-host "${LOCAL_IP}" \
      --remote-user "${USER_NAME}" \
      --key /root/.ssh/id_audit \
      --json /app/audit_distant.json

  echo "Rapport enregistré dans $(pwd)/audit_distant.json"
fi

echo
echo "Audit terminé."
