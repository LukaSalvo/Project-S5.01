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


