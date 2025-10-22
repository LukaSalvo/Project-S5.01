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

##  2. Génération et configuration de la clé SSH

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

---

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


## 7. Résumé rapide

| Étape | Commande | Description |
|--------|-----------|-------------|
| Générer la clé SSH | `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_audit` | Crée une clé dédiée à l’audit |
| Copier la clé sur la cible | `ssh-copy-id -i ~/.ssh/id_audit.pub user@IP` | Autorise l’accès sans mot de passe |
| Tester la connexion | `ssh -i ~/.ssh/id_audit user@IP` | Vérifie la configuration |
| Audit terminal | `docker run ... dacs-audit:latest ...` | Audit en direct dans le terminal |
| Audit JSON | `docker run ... --json audit_distant.json` | Sauvegarde du résultat en fichier |

---

## Conclusion

Le **client SSH DACS AUDIT** permet d’effectuer des audits distants sans installer Ruby ni dépendances sur la machine cible.  
L’ensemble des commandes s’exécute **depuis un conteneur Docker léger**, garantissant portabilité et sécurité.

---
