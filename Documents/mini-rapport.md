# Mini-rapport – Projet Audit et Déploiement  
**Auteurs :** Amin Belalia, Luka Salvo, Léo Candido Della Mora
**BUT Informatique 3A – Parcours DACS**  

---

## Partie 1 – Audit système  

Cette première partie du projet avait pour but de réaliser un audit complet d’un système Linux. L’objectif était de comprendre comment récupérer les principales informations sur une machine et de se familiariser avec les commandes Unix les plus utiles pour ce type d’analyse.  


Nous avons commencé par identifier les éléments essentiels à extraire : le **nom** et la **version de la machine**, le **noyau** utilisé, la **distribution**, le **temps de fonctionnement**, la **charge moyenne**, ainsi que les **ressources matérielles** telles que la **mémoire**, la **swap** et l’**espace disque disponible**.  
Ces données constituent la base d’un audit système, car elles permettent d’évaluer la stabilité et les performances globales de l’environnement étudié.

Par la suite, l’analyse s’est étendue à la configuration réseau, incluant **la liste des interfaces disponibles**, **les adresses IP** et **MAC associées**, ainsi que l’observation du **trafic réseau**.  
Ces informations sont cruciales pour comprendre l’architecture de communication du système et repérer d’éventuelles anomalies ou saturations.

Un autre aspect important de cet audit concernait la gestion des utilisateurs. Nous avons recensé les comptes présents sur le système en distinguant les utilisateurs « **humains** » des comptes techniques (grâce à l’analyse des identifiants numériques), puis identifié les **utilisateurs actuellement connectés**.  
Cela permet d’avoir une meilleure visibilité sur les accès et l’utilisation réelle du serveur.


L’audit s’est poursuivi par l’observation des processus actifs. Nous avons identifié ceux qui consommaient le plus de **CPU**, de **mémoire** ou de **bande passante**, afin de mieux comprendre le comportement de la machine. Pour terminer, nous avons vérifié l’état de certains services importants comme **sshd**, **cron** et **docker**, indispensables au bon fonctionnement du système.


Cette étape nous a permis de revoir les bases des commandes Unix tout en apprenant à organiser les informations obtenues de façon claire et utile. Elle sert aussi de base pour la suite du projet, où nous devrons automatiser tout ce travail avec un script Ruby.  

---

## Partie 2 – Automatisation via un script Ruby

Dans cette seconde partie, l’objectif principal était d’automatiser l’ensemble de l’audit réalisé précédemment à l’aide d’un script Ruby.  
Cette étape visait à reproduire toutes les commandes manuelles de la première partie de manière dynamique et structurée.

---

#### Conception du script `script.rb`

Le script développé, nommé **script.rb**, a pour but d’effectuer un audit complet d’un système Linux, en collectant automatiquement toutes les informations nécessaires :  
- Informations générales du système (distribution, noyau, uptime, charge moyenne)  
- Ressources matérielles (mémoire, swap, espace disque)  
- Interfaces réseau et adresses IP  
- Utilisateurs humains et utilisateurs connectés  
- Processus les plus consommateurs (CPU, mémoire, réseau)  
- État des services essentiels (**sshd**, **cron**, **docker**, etc.)  

L’ensemble de ces données est structuré sous forme de tableau associatif Ruby (*hash*), puis exporté au format **JSON** pour un usage automatisé (analyse, supervision ou archivage).

---

#### Structure et fonctionnement du script

Le script repose sur une architecture simple mais modulaire :  
- La méthode `run_cmd` permet d’exécuter des commandes locales ou distantes selon les paramètres passés en argument.  
- Si l’option `--remote-host` est spécifiée, le script utilise une connexion **SSH** sécurisée via une clé privée pour exécuter les commandes à distance.  
- Des expressions régulières sont employées pour filtrer et formater les résultats (extraction des utilisateurs, des processus, ou des statistiques réseau).  
- Le résultat est ensuite soit affiché directement dans le terminal avec un format clair et coloré, soit exporté dans un fichier **JSON** à l’aide de l’option `--json`.  

Cette double approche (affichage terminal ou fichier JSON) offre à la fois une lecture humaine immédiate et logicielle avec d’autres outils d’analyse.

---

#### Audit distant via SSH

Une évolution majeure de ce travail a consisté à rendre le script compatible avec un audit distant via **SSH**.  
Grâce aux options suivantes :  

```
--remote-host <IP> --remote-user <utilisateur> --key <chemin_vers_cle>
```

le script peut auditer n’importe quelle machine Linux distante de manière sécurisée et sans installation supplémentaire.

---

## Partie 3 – Déploiement et conteneurisation avec Docker

Afin de rendre l’audit portable et indépendant du système hôte, nous avons encapsulé le script Ruby dans une image Docker :  
**dacs-audit:latest**  

Cette image permet d’exécuter le script sur n’importe quelle machine, sans installation préalable de Ruby ni de dépendances.

---

#### 3.1. Script d’automatisation : `config.sh`

Ce script a été conçu pour simplifier la configuration initiale et le lancement de l’audit.  
Il effectue les étapes suivantes :  

1. Vérifie la présence de Docker.  
2. Génère automatiquement une clé SSH dédiée à l’audit (`~/.ssh/id_audit`) si elle n’existe pas.  
3. Ajoute la clé publique dans `authorized_keys` pour autoriser les connexions locales sans mot de passe.  
4. Teste la connexion SSH locale pour s’assurer du bon fonctionnement.  
5. Construit l’image Docker `dacs-audit:latest` si elle est absente.  
6. Propose deux modes d’exécution :  
   - Affichage direct dans le terminal  
   - Export au format JSON  

Ce script permet de déployer et d’exécuter l’audit de manière entièrement automatisée, sans intervention manuelle complexe.

---

## Partie 4 – Guide d’utilisation : Client SSH Docker

Un guide détaillé (**CLIENT_SSH_GUIDE.md**) a été rédigé pour accompagner l’utilisation du client SSH.  
Il décrit :  

- La génération et la configuration de la clé SSH.  
- La vérification de la connectivité réseau (*ping*, port 22).  
- La construction de l’image Docker.  
- Les commandes pour exécuter l’audit avec ou sans export JSON.  
- Les explications techniques des options Docker (`--network host`, `-v`, etc.).  

Ce guide vise à rendre le processus accessible à tout utilisateur, même sans connaissance approfondie de Docker ou SSH.

---

## Partie 5 - Conclusion

Au terme de ce projet, nous avons conçu un outil d’audit **complet, portable et automatisé**, capable d’être exécuté sur n’importe quelle machine Linux via Docker et SSH.
L’audit produit est clair, structuré et exploitable sous forme de rapport JSON ou directement dans le terminal.

L’intégration de Ruby, Docker et SSH a permis de créer une solution conforme aux exigences d’un environnement professionnel : **sécurisée, reproductible et maintenable**.

Puis le fichier d'automatisation ainsi que le guide détaillé permet une mise en œuvre **rapide, fiable et accessible** de l’outil sur n’importe quel poste.

Le fichier `config.sh` automatise la configuration complète du client SSH et du conteneur Docker. Et de son côté, le guide `README`.md fournit une documentation claire et structurée, permettant à tout utilisateur de **comprendre, installer et exécuter** l’audit en toute autonomie.

