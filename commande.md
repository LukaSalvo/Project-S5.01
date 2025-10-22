# Audit système – Projet tuteuré (pré-SAÉ)
**Auteurs :** Amin Belalia, Luka Salvo, Léo Candido Della Mora 
**BUT Informatique 3A – Parcours DACS**  

---

## Partie 1 : Audit système

### - Nom de la machine, distribution, version du noyau
**Commandes utilisées :**
```
uname -a
lsb_release -a
uname -r
```
**Commentaires :**
- `uname -a` affiche toutes les informations du système : nom du noyau, version, architecture, et nom de la machine.  
- `lsb_release -a` donne les informations précises de la distribution (nom, version, ID).  
- `uname -r` extrait uniquement la version du noyau Linux, utile pour vérifier les mises à jour système.

---

### Uptime et charge moyenne
**Commandes utilisées :**
```bash
uptime
top
cat /proc/loadavg
```
**Commentaires :**
- `uptime` indique depuis combien de temps la machine est allumée et affiche la charge moyenne sur 1, 5 et 15 minutes.  
- `top` permet de visualiser en temps réel l’utilisation du CPU, de la mémoire et la charge du système.  
- `cat /proc/loadavg` lit directement le fichier système contenant la charge moyenne brute (utile dans les scripts d’audit).

---

### Mémoire et swap disponibles/utilisés
**Commandes utilisées :**
```bash
free -h
vmstat
```
**Commentaires :**
- `free -h` affiche la mémoire totale, utilisée et libre, ainsi que la swap, avec des unités lisibles (`-h` = human readable).  
- `vmstat` fournit une vue d’ensemble du système : mémoire, processus, entrées/sorties et swap, utile pour détecter les goulets d’étranglement.

---

### Interfaces réseau (adresses MAC et IP)
**Commandes utilisées :**
```bash
ip a
ifconfig
```
**Commentaires :**
- `ip a` (ou `ip addr`) liste toutes les interfaces réseau, leurs adresses IP (IPv4/IPv6) et leurs adresses MAC.  
- `ifconfig` donne les mêmes informations mais sous un format plus ancien ; pratique pour compatibilité ou vérification rapide.

---

### Utilisateurs humains (uid ≥ 1000) + ceux connectés actuellement
**Commandes utilisées :**
```bash
getent passwd
who
w
```
**Commentaires :**
- `getent passwd` liste tous les utilisateurs enregistrés sur le système ; en filtrant ceux avec `uid >= 1000`, on obtient les utilisateurs humains.  
- `who` affiche les utilisateurs actuellement connectés et leurs terminaux.  
- `w` fournit des détails supplémentaires comme l’activité en cours et le temps d’inactivité.

---

### Espace disque par partition
**Commandes utilisées :**
```bash
df -h
```
**Commentaires :**
- `df -h` montre l’espace total, utilisé et disponible sur chaque partition montée.  
- L’option `-h` rend les tailles lisibles (Go, Mo, etc.), facilitant l’interprétation.

---

### Processus les plus consommateurs de CPU et mémoire
**Commandes utilisées :**
```bash
ps aux --sort=-%cpu | head -n 10
ps aux --sort=-%mem | head -n 10
```
**Commentaires :**
- `ps aux` affiche tous les processus en cours avec leurs ressources utilisées.  
- Le tri par `--sort=-%cpu` ou `--sort=-%mem` classe les processus du plus gourmand au moins gourmand.  
- `head -n 10` limite l’affichage aux dix premiers pour une lecture rapide.

---

### Processus consommateurs de trafic réseau (paramétrable)
**Commandes utilisées :**
*(outils comme nethogs, ss, iftop)*

**Commentaires :**
- `nethogs` affiche le trafic réseau par processus, en temps réel.  
- `ss` permet de visualiser les connexions réseau actives et les sockets utilisés.  
- `iftop` affiche le débit entrant/sortant sur chaque interface réseau, utile pour repérer les processus générant beaucoup de trafic.

---

### Statut de services clés (ex: sshd, cron, docker)
**Commandes utilisées :**
```bash
systemctl status sshd
systemctl is-active docker
```
**Commentaires :**
- `systemctl status sshd` affiche l’état complet du service SSH (actif, en erreur, logs récents).  
- `systemctl is-active docker` vérifie rapidement si le service Docker est en cours d’exécution (`active` ou `inactive`).
