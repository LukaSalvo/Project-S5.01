# Rapport— Partie Supervision (Prometheus / Grafana / agents)


## Contexte et objectif
Cette partie de la SAE met en place une solution de supervision locale pour auditer des machines (locales ou distantes) et remonter des métriques vers Prometheus, avec visualisation dans Grafana. L'implémentation fournie contient :
- un Docker (Prometheus + Grafana + 2 agents),
- des agents Ruby exposant /metrics compatibles Prometheus,
- des dashboards Grafana pré-provisionnés,
- une configuration Prometheus ciblant les agents.

---

## Contenu du dossier Supervision (fichiers fournis)

- docker-compose.yml — définition des services : agent1, agent2, prometheus, grafana
- prometheus/prometheus.yml — jobs : prometheus, agent1, agent2
- agent/
  - Dockerfile — image Ruby + dépendances, expose le script agent
  - script.rb — agent Ruby (Sinatra) exposant /metrics et /health ; mode local ou audit distant via SSH
- grafana/
  - provisioning/datasources/prometheus.yml — datasource Prometheus (url: http://prometheus:9090)
  - provisioning/dashboards/default.yml et dashboards/dashboards.yml — provisioning des dashboards
  - dashboards/system_dashboard.json et system_metrics.json — dashboards préconfigurés

---

## Description synthétique des composants

1) Agents (agent1 & agent2)
- Image construite depuis Supervision/agent/Dockerfile (ruby:3.0-slim).
- Le script Supervision/agent/script.rb démarre un serveur Sinatra sur le port défini par l’environnement (4567 pour agent1, 4568 pour agent2).
- Endpoints :
  - /metrics — renvoie des métriques Prometheus au format texte.
  - /health — renvoie {"status":"healthy","timestamp":...}.
- Mécanique :
  - Mode LOCAL (par défaut) : lit /proc et autres fichiers locaux.
  - Mode SSH distant : si REMOTE_HOST, REMOTE_USER et SSH_KEY_PATH sont fournis, exécute les commandes à distance via ssh pour collecter les mêmes métriques.
- Métriques exposées (exemples) :
  - load_average_1min, load_average_5min, load_average_15min
  - uptime_seconds
  - memory_total_bytes, memory_used_bytes, memory_available_bytes, memory_usage_percent
  - swap_total_bytes, swap_used_bytes
  - cpu_usage_percent
  - disk_total_bytes, disk_used_bytes, disk_available_bytes, disk_usage_percent
  - service_status{service="..."} (1 = active, 0 = inactive)
  - tcp_connections_total
  - processes_total

2) Grafana
- Datasource Prometheus provisionnée : points vers http://prometheus:9090
- Dashboards fournis et provisionnés automatiquement via le dossier ./grafana/provisioning :
  - system_dashboard.json et system_metrics.json : affichent CPU, mémoire, load average, statut des services, etc.
- Admin password défini via docker-compose (GF_SECURITY_ADMIN_PASSWORD=admin)

3) Docker compose
- Fichier : Supervision/docker-compose.yml
- Expose les ports locaux :
  - 4567 → agent1
  - 4568 → agent2
  - 9090 → Prometheus
  - 3000 → Grafana
- Monte la clé SSH du host (HOST_SSH_KEY) dans le conteneur agent en lecture seule sur /root/.ssh/id_audit pour permettre audits distants via SSH.

---

## Mode d'emploi (déploiement et vérification)

Prérequis :
- Docker installé.
- Ports 4567, 4568, 9090, 3000 libres.

Lancement :
- Utiliser le script fourni : Supervision/script.sh
  - (Ce script prépare l'environnement, copie la clé SSH si nécessaire et lance docker-compose up -d --build)
- Ou manuellement depuis Supervision/ :
  - docker compose down -v
  - docker compose up -d --build

Vérifications rapides :
- Agent1 metrics : curl http://localhost:4567/metrics
- Agent2 metrics : curl http://localhost:4568/metrics
- Prometheus : http://localhost:9090
- Grafana : http://localhost:3000 (admin/admin — mot de passe défini par docker-compose)

Vérifier la connexion SSH depuis un agent (si audit distant) : la clé montée dans le conteneur doit permettre ssh sans mot de passe vers REMOTE_HOST.

---

## Dépannage rapide
- docker compose non trouvé : installer Docker compose ou adapter les commandes.
- /metrics vide ou 404 :
  - vérifier les logs du conteneur agent : docker logs dacs_agent1
  - s’assurer que le script Ruby a démarré sans erreur (dépendances gem, permission clé SSH).
- Erreur SSH : testez `ssh -i /chemin/vers/id_audit user@host` depuis la machine hôte; ajustez permissions/authorized_keys.

---

## Améliorations possibles
- Remplacer montage direct de clé par Docker secrets / gestionnaire de secrets.
- Paramétrer ports et adresses depuis des variables d’environnement plus explicites.
- Ajouter des dashboards supplémentaires et exporter les tableaux de bord utiles pour la soutenance.

---

