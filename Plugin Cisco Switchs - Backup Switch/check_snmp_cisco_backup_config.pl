#!/usr/bin/perl -w
## Definition des variables et des fonctions à  utiliser.
use strict;
use Getopt::Long;
use vars qw($opt_h $opt_community $opt_iprouteur $opt_iptftp $opt_sauvegarde $config $chemin_sauvegarde $output );
use lib "/usr/local/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
## Fonction à  rajouter depuis le CPAN, pour effectuer une sauvegarde du routeur avec PERL
use Net::OpenSSH;
use Net::SNMP;
use Cisco::CopyConfig;

## Définition des variables à  saisir pour chaque routeur concerné
Getopt::Long::Configure('bundling');
GetOptions
("h"	=>	\$opt_h,		"help"		=> \$opt_h,
 "C=s"	=>	\$opt_community,	"community=s"	=> \$opt_community,
 "I=s"  =>	\$opt_iprouteur,	"iprouteur=s"	=> \$opt_iprouteur, 
 "T=s"	=>	\$opt_iptftp,		"iptftp=s"	=> \$opt_iptftp,
 "F=s"	=>	\$opt_sauvegarde,	"sauvegarde=s"	=> \$opt_sauvegarde);


if ($opt_h){
  print "Usage du plugin :\n";
  print "-h (--help) 		Affiche l'aide\n";
  print "-C (--community)	Valeur de la communaute\n";
  print "-I (--iprouteur)	Adresse IP du routeur\n";
  print "-T (--iptftp)		Adresse IP serveur TFTP\n";
  print "-F (--sauvegarde) 	Nom fichier de sauvegarde\n";
  exit ($ERRORS{'UNKNOWN'});
}

if (!defined($opt_community)){
   print "Vous devez saisir une communaute\n";
   exit ($ERRORS{'UNKNOWN'});
}
elsif (!defined($opt_iprouteur)){
   print "Vous devez saisir l'adresse IP du routeur-switch a sauvegarder\n";
   exit ($ERRORS{'UNKNOWN'});
}
elsif (!defined($opt_iptftp)){
   print "Vous devez saisir l'adresse IP du serveur TFTP\n";
   exit ($ERRORS{'UNKNOWN'});
}
elsif (!defined($opt_sauvegarde)){
   print "Vous devez saisir le nom du fichier de sauvegarde\n";
   exit ($ERRORS{'UNKNOWN'});
}


## Avec la fonction Cisco::CopyConfig, il est impossible d 'Ã©craser le dernier fichier de sauvegarde
## vous devez donc avant d'effectuer une sauvegarde le supprimer. Si le fichier ne se trouve pas sur le même serveur
## vous devrez utiliser par exemple le module CPAN Net::OpenSSH pour se connecter en ssh dessus et effectuer vos modifications.
## Initialisation des variables pour se connecter au serveur TFTP
my $username = "administrateur";
my $password = "vrpbjr";

## Initialisation des variables diverses
my $output = "";
my $status = 'OK';
my $chemin_sauvegarde = "";
my $taille = "";
my $date_format = "";
my $snmp_timeout_in_seconds = 30;

## Declaration des variables pour récupérer et manipuler la date et l'heure
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)=localtime(time);
$year+=1900;
$mon  = sprintf("%02d",$mon+1);
$mday = sprintf("%02d",$mday);
$hour = sprintf("%02d",$hour);
$min  = sprintf("%02d",$min);
$sec  = sprintf("%02d",$sec);
$date_format="$mday-$mon-$year $hour:$min:$sec";


## Le paramètre strict_mode => 0 permet de s'affranchir du message de sécurité suivant ../.libnet-openssh-perl/ is not secure
## si on exÃ©cute le script en mode non root.
## Permet de supprimer le fichier de configuration existant si il existe sur le serveur TFTP
## avant la nouvelle sauvegarde. la connexion s'effectue en SSH.
my $ssh2 = Net::OpenSSH->new($opt_iptftp, user => $username, password => $password, strict_mode => 0);
if ($ssh2->error) {
      $status = 'CRITICAL';
      $output = $output . " Backup Config Error :" . $ssh2->error; 
      printf "$status %s \n", $output;
      exit $ERRORS{$status}; 
    }
    else {
    $ssh2->system("cd /tftpboot/; rm -f $opt_sauvegarde ");
    }
    

## Connexion au routeur/switch pour effectuer la sauvegarde
$config = Cisco::CopyConfig->new(
                     Host => $opt_iprouteur,
                     Comm => $opt_community,
                     Tmout => $snmp_timeout_in_seconds
    );
    


## Backup de la configuration du routeur/switch vers le serveur TFTP
if ($config->copy($opt_iptftp, $opt_sauvegarde)) {
      $chemin_sauvegarde="/tftpboot/" .$opt_sauvegarde;
      ## Commande permettant de vérifier que le fichier existe bien sur le serveur TFTP et/ou a bien été copié
      ## On rÃ©cupÃ¨re la sortie de la commande echo $? 0: success 1:fail
       my $existfichier = $ssh2->capture("test -f $chemin_sauvegarde ; echo $?");
          if  ($existfichier != 1) {
            ## Commande permettant de récupérer la taille d'un fichier via la commande stat sur un hôte distant
            ## en utilisant le module CPAN Net::OpenSSH.
            my $taille = $ssh2->capture("cd /tftpboot/; stat -c%s $chemin_sauvegarde");
            $taille = $taille /1000;
            $status = 'OK';
            $output = $output . " Last Backup Config : " . $date_format ." - Fichier : " . $opt_sauvegarde ." - Taille : " . $taille . " Ko";
          }
           else {
            $status = 'CRITICAL';
            $output = "Erreur de copie du fichier de backup ou fichier inacessible.";
          }
}
 else {
  $status = 'CRITICAL';
  $output = $output . " Backup Config Error : " . $config->{err};
}


## Affichage du résultat dans Centreon
printf "$status %s \n", $output;
exit $ERRORS{$status};

