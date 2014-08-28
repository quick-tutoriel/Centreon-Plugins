#!/usr/bin/perl -w
## Definition des variables et des fonctions Ã  utiliser.
use strict;
use Getopt::Long;
use vars qw($opt_h $opt_community $opt_iprouteur $opt_iptftp $opt_sauvegarde $config $chemin_sauvegarde $output );
use lib "/usr/local/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
## Fonction a  rajouter depuis le CPAN, pour effectuer une sauvegarde du routeur avec PERL
use Net::Telnet;
use Net::SNMP;
use File::stat;
use Cisco::CopyConfig;

## Definition des variables a  saisir pour chaque routeur concerne
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

## Avec la fonction Cisco::CopyConfig, il est impossible d 'ecraser le dernier fichier de sauvegarde
## vous devez donc avant d'effectuer une sauvegarde le supprimer. Si le fichier ne se trouve pas sur le meme serveur
## vous devrez utiliser par exemple le module CPAN Net::OpenSSH pour se connecter en ssh dessus et effectuer vos modifications.
## Initialisation des variables pour se conencter au serveur TFTP
my $username = "";
my $password = "";

## Initialisation des variables diverses
my @line;
my $output = "";
my $status = 'OK';
my $chemin_sauvegarde = "";
my $date_format = "";
my $snmp_timeout_in_seconds = 30;
my $chemin_tftp = "/tftpboot/";
my $prompt = '/.*[\$#:>\]\%] *$/';
my $pause = 5;
my $perfdata = "";

## Declaration des variables pour recuperer et manipuler la date et l'heure
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)=localtime(time);
$year+=1900;
$mon  = sprintf("%02d",$mon+1);
$mday = sprintf("%02d",$mday);
$hour = sprintf("%02d",$hour);
$min  = sprintf("%02d",$min);
$sec  = sprintf("%02d",$sec);
$date_format="$mday-$mon-$year $hour:$min:$sec";

## Connexion Telnet au serveur TFTP pour supprimer l'ancienne sauvegarde. Il est necessaire de supprimer avant le dernier fichier
## de sauvegarde sinon le backup echoue.
my $telnet2 = new Net::Telnet (Timeout => 20, Prompt => $prompt, Errmode=>'return');
 
if ($telnet2->open($opt_iptftp))
{
$telnet2 -> login ($username, $password);
$telnet2 -> cmd ("cd $chemin_tftp");
$telnet2 -> cmd ("rm -f $opt_sauvegarde");
}
else
{
$status = 'CRITICAL';
$output = $output . " Connexion Error :" . $telnet2->error; 
printf "$status %s \n", $output;
exit $ERRORS{$status}; 
}
    
## Connexion au routeur/switch pour effectuer la sauvegarde
$config = Cisco::CopyConfig->new(
                     Host => $opt_iprouteur,
                     Comm => $opt_community,
                     Tmout => $snmp_timeout_in_seconds
);
    
## Backup de la configuration du routeur/switch vers le serveur TFTP
if ($config->copy($opt_iptftp, $opt_sauvegarde)) {
      $chemin_sauvegarde= $chemin_tftp .$opt_sauvegarde;
      $telnet2 -> cmd ("cd $chemin_tftp");
       ## Permet de modifier les droits du fichier de sauvegarde
       $telnet2 -> cmd ("chmod og+r+w $opt_sauvegarde");
       ## Commande permettant de recuperer la taille d'un fichier
       @line = $telnet2 -> cmd ("stat -c%s $chemin_sauvegarde");
       my $taille = $line[0]/1000;
       ## Test verifiant la taille du fichier sauvegardé
       if ($taille > 0) 
       {
          $status = 'OK';
          $perfdata = $taille;
          $output = " Last Backup Config : " . $date_format .  " - Fichier : " . $opt_sauvegarde . " - Taille : " . $taille . " Ko";
       }
       else
       {
         $status = 'CRITICAL';
         $perfdata = $taille;
         $output = " Backup Config Error (Taille fichier null) : " . $date_format .  " - Fichier : " . $opt_sauvegarde . " - Taille : " . $taille . " Ko";
       }
}
 else {
  $status = 'CRITICAL';
  $output = $output . " Backup Config Error : " . $config->{err};
}

## Affichage du resultat dans Centreon
printf "$status %s | TAILLE_BACKUP=%d \n", $output, $perfdata;
exit $ERRORS{$status};
