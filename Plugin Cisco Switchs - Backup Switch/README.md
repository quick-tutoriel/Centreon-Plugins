Centreon-Plugins
================

Retrouver tous les conseils détaillés sur l'utilisation du plugin sur le blog Quick-Tutoriel à cette adresse : http://quick-tutoriel.com/script-perl-centreon-permettant-sauvegarder-switch-routeur-cisco/

V2.0 (28/08/2014) : 
- Le module Net::OpenSSH a été remplacé par le module Net::Telnet pour supprimer les derniers fichiers de sauvegarde sur le serveur TFTP. Net::OpenSSH génère des erreurs lorsqu'on sauvegarde plusieurs switchs en parallèle.
- Ajout d'une variable PERFDATA permettant de récupérer la taille du fichier de backup et de créer un graphique dans Centreon pour suivre l'évolution de la taille du fichier.

V1.0 (01/08/2014) : 
- Version Initiale
