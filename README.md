# DACS AUDIT — Guide Client SSH

**Auteurs :** Amin Belalia, Luka Salvo, Léo Candido Della Mora  
**BUT Informatique 3A – Parcours DACS**

## Objectif

Ce document explique comment configurer et exécuter le **client SSH Docker** permettant de lancer un audit distant sur une machine Linux à l’aide du script inclus dans l’image `dacs-audit:latest`.

Le conteneur embarque uniquement **Ruby**, et exécute le script en se connectant à la machine distante via SSH grâce à une **clé d’authentification sécurisée**.

---

## 1. Pré-requis

### Logiciels nécessaires
- Docker installé et fonctionnel (`docker --version`)
- Accès SSH à la machine distante (port 22 ouvert)
- Image Docker `dacs-audit:latest` déjà construite et disponible en local

---

## 2. Génération et configuration de la clé SSH

### 2.1. Générer une clé dédiée à l’audit
Sur ta machine cliente :
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_audit
```

> Appuie sur **Entrée** à chaque question pour ne pas mettre de passphrase.

Cela crée deux fichiers :
```
~/.ssh/id_audit        ← clé privée
~/.ssh/id_audit.pub    ← clé publique
```

---

### 2.2. Copier la clé publique sur la machine distante
```bash
ssh-copy-id -i ~/.ssh/id_audit.pub user@IP_DISTANTE
```

Exemple :
```bash
ssh-copy-id -i ~/.ssh/id_audit.pub user@***.**.*.*
```

Cela ajoute ta clé dans le fichier :
```
~/.ssh/authorized_keys
```
de la machine distante, te permettant une connexion sans mot de passe.

---

### 2.3. Tester la connexion SSH
```bash
ssh -i ~/.ssh/id_audit user@***.**.*.*
```

Si tu accèdes sans mot de passe → la clé est correctement installée.  
Si un mot de passe est demandé, revérifie les permissions :
```bash
chmod 600 ~/.ssh/id_audit
chmod 700 ~/.ssh
```

---

## 3. Vérifier la connectivité réseau

Avant de lancer l’audit, vérifie que la machine distante est accessible :

### - Test de ping :
```bash
ping ***.**.*.*
```

### - Vérifier que le port SSH (22) est ouvert :
```bash
nmap -p 22 ***.**.*.*
```

> Si le port 22 est **fermé** ou la machine **injoignable**, aucune connexion SSH ne sera possible.

---

## 4. Exécution du client SSH Docker

### Se placer dans le dossier du projet
```bash
cd ~/Documents/BUT_informatique_DACS/3_annee/SAE/Project-S5.01
```

### Construire l'image (si besoin)
```bash
docker build -t dacs-audit:latest .
```

### Audit distant avec affichage direct dans le terminal
```bash
docker run --rm -it --network host \
  -v ~/.ssh/id_audit:/root/.ssh/id_audit:ro \
  dacs-audit:latest --remote-host ***.**.*.* --remote-user user --key /root/.ssh/id_audit
```

Le rapport d’audit s’affiche directement dans ton terminal avec les sections colorées et les titres ASCII.

---

### Audit distant avec export JSON
```bash
docker run --rm -it --network host \
  -v ~/.ssh/id_audit:/root/.ssh/id_audit:ro \
  -v $(pwd):/app \
  dacs-audit:latest --remote-host ***.**.*.* --remote-user user --key /root/.ssh/id_audit --json /app/audit_distant.json
```

Le résultat est enregistré localement dans :
```
./audit_distant.json
```

Tu peux le visualiser avec :
```bash
cat audit_distant.json | jq
```
ou simplement :
```bash
cat audit_distant.json
```

---

## 5. Détails techniques

| Élément | Description |
|----------|--------------|
| `--network host` | Le conteneur partage le réseau de la machine hôte (permet le SSH) |
| `-v ~/.ssh/id_audit:/root/.ssh/id_audit:ro` | Monte la clé privée dans le conteneur (lecture seule) |
| `-v $(pwd):/app` | Monte le dossier du projet pour récupérer le fichier JSON |
| `dacs-audit:latest` | Image Docker contenant le script d’audit Ruby intégré |
| `--remote-host`, `--remote-user`, `--key` | Paramètres de connexion SSH pour l’audit distant |

---

## 6. Usage — Partie Supervision (Prometheus / Grafana / agents)

Cette section explique comment démarrer et utiliser la partie supervision fournie dans le dossier `Supervision/` : elle contient une stack Docker (Prometheus + Grafana + 2 agents Ruby exposant /metrics) et des dashboards Grafana pré-provisionnés.

### Prérequis
- Docker & Docker Compose (v2) installés.
- Ports libres : 4567, 4568, 9090, 3000.
- Clé SSH créée et autorisée sur la ou les machines cibles si tu veux utiliser l'option d'audit distant.

### Fichiers importants
- Supervision/docker-compose.yml — définition des services (agent1, agent2, prometheus, grafana).
- Supervision/agent/script.rb — code de l'agent (expose /metrics, /health ; support SSH distant).
- Supervision/prometheus/prometheus.yml — jobs Prometheus (agent1, agent2).
- Supervision/grafana/* — provisioning des datasources et dashboards.

### Démarrage automatique (script fourni)
Le dossier `Supervision/` contient un script d'orchestration (`Supervision/script.sh`) qui :
- prépare l'environnement (.env),
- monte/copier la clé si nécessaire,
- relance la stack : `docker compose down --remove-orphans -v` puis `docker compose up -d --build`,
- effectue des vérifications de base sur les endpoints /metrics.

Pour l'utiliser :
```bash
cd Supervision
chmod +x script.sh
./script.sh
```

### Démarrage manuel
Si tu préfères lancer manuellement :
```bash
cd Supervision
docker compose down -v
docker compose up -d --build
```

### Vérifications après démarrage
- Agent1 metrics : http://localhost:4567/metrics
- Agent2 metrics : http://localhost:4568/metrics
- Prometheus UI : http://localhost:9090
- Grafana UI : http://localhost:3000 (admin password défini via docker-compose : `admin`)

Exemple de vérification CLI :
```bash
curl -s http://localhost:4567/metrics | head -n 20
curl -s http://localhost:4568/metrics | head -n 20
```

### Remarques de sécurité et bonnes pratiques
- La clé SSH est montée dans les containers en lecture seule ; en contexte réel, privilégier les secrets (Docker secrets / Vault) et éviter de garder des clés privées accessibles.
- Vérifier les permissions (600) de la clé privée montée.
- Ajuster les variables du `.env` (ports, hôtes) plutôt que modifier le docker-compose si tu veux déployer sur un autre réseau.

### Dépannage rapide
- Si `/metrics` renvoie une erreur : inspecte les logs des agents :
  ```bash
  docker logs dacs_agent1
  docker logs dacs_agent2
  ```
- Si Grafana n'apparaît pas : vérifier `docker ps` et `docker logs dacs_grafana`.
- Si SSH échoue depuis l'agent : tester la connexion depuis l'hôte avec la même clé :
  ```bash
  ssh -i /chemin/vers/id_audit user@REMOTE_HOST
  ```

---

## 7. Résumé rapide (client SSH + supervision)
| Étape | Commande | Description |
|--------|-----------|-------------|
| Générer la clé SSH | `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_audit` | Crée une clé dédiée à l’audit |
| Copier la clé sur la cible | `ssh-copy-id -i ~/.ssh/id_audit.pub user@IP` | Autorise l’accès sans mot de passe |
| Tester la connexion | `ssh -i ~/.ssh/id_audit user@IP` | Vérifie la configuration |
| Audit terminal | `docker run ... dacs-audit:latest ...` | Audit en direct dans le terminal |
| Audit JSON | `docker run ... --json audit_distant.json` | Sauvegarde du résultat en fichier |
| Démarrer supervision (script) | `cd Supervision && ./script.sh` | Déploie Prometheus/Grafana/agents |
| Vérifier /metrics | `curl http://localhost:4567/metrics` | S’assurer que les agents exposent des métriques |

---

## Conclusion

Le **client SSH DACS AUDIT** permet d’effectuer des audits distants sans installer Ruby ni dépendances sur la machine cible. La partie **Supervision** fournie permet de centraliser et visualiser ces métriques via Prometheus et Grafana, pour faciliter l’analyse et la démonstration.
