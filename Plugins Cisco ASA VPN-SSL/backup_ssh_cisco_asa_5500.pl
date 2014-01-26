#!/usr/bin/perl
##
## Definition des variables et des fonctions à utiliser. 
## Fonction à  rajouter depuis le CPAN, pour effectuer une sauvegarde du commutateur avec PERL
##
use strict;
use Net::Telnet;
use Getopt::Long;
use Net::SSH::Expect;
use Net::SNMP;
use File::stat;
use FileHandle;
use vars qw($opt_h $opt_ipcommutateur $opt_iptftp $opt_sauvegarde $chemin_sauvegarde $output);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);

## Initialisation des variables
## Login mot de passe pour le serveur TFTP
my $username = "";
my $password = "";
## Login mot de passe pour la connexion a appliance ASA 5500
my $name = "";
my $pass = "";
## Autres variables
my $output = "";
my $chemin_sauvegarde = "";
my $chemin_tftp = "/tftpboot/";
my $taille = "";
my $date_format = "";
my $status = 'OK';
my $prompt = '/.*[\$#:>\]\%] *$/';
my @line;
## Variable permettant d'inclure une pause pour le temps de copie du fichier sur le serveur TFTP
## pour les réseaux lents et pour éviter des erreurs
my $pause = 10;
## Commande à  passer pour sauvegarder la configuration depuis l'appliance
my $command1 = "copy /noconfirm running-config tftp://";

## Declaration des variables pour récupérer et manipuler la date et l'heure
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)=localtime(time);
$year+=1900;
$mon  = sprintf("%02d",$mon+1);
$mday = sprintf("%02d",$mday);
$hour = sprintf("%02d",$hour);
$min  = sprintf("%02d",$min);
$sec  = sprintf("%02d",$sec);
$date_format="$mday-$mon-$year $hour:$min:$sec";


## Plugin var init
Getopt::Long::Configure('bundling');
GetOptions
("h"	=>	\$opt_h,		"help"		=> \$opt_h,
 "I=s"  =>	\$opt_ipcommutateur,	"ipcommutateur=s"=> \$opt_ipcommutateur, 
 "T=s"	=>	\$opt_iptftp,		"iptftp=s"	=> \$opt_iptftp,
 "F=s"	=>	\$opt_sauvegarde,	"sauvegarde=s"	=> \$opt_sauvegarde);


## Affiche l'aide pour exécuter le plugin avec le paramètre -h
## et vérifie si tous les arguments obligatoires sont saisis
if ($opt_h){
  print "Usage du plugin :\n";
  print "-h (--help) 		Affiche l'aide\n";
  print "-I (--ipcommutateur)	Adresse IP de ASA 5500\n";
  print "-T (--iptftp)		Adresse IP serveur TFTP\n";
  print "-F (--sauvegarde) 	Nom fichier de sauvegarde\n";
  exit ($ERRORS{'UNKNOWN'});
}

if (!defined($opt_ipcommutateur)){
   print "Vous devez saisir l'adresse IP de ASA 5500 a sauvegarder\n";
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

## Connexion au serveur TFTP pour supprimer l'ancienne sauvegarde. Il est nécessaire de supprimer avant le dernier fichier
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

## Connexion en SSH a l'appliance Cisco VPN-SSl 5500
my $ssh2 = Net::SSH::Expect->new(
  host     => $opt_ipcommutateur,
  password => $pass,
  user     => $name,
  raw_pty  => 1
);


my $login_output  = $ssh2->login();
## Passage en mode avancée
$ssh2->send("enable");
$ssh2->waitfor( 'Password:\s*\z', 2 ) or die "prompt 'password' not found after 2 seconds";
## Envoie du mot de passe pour se connecté
$ssh2->send($pass);
$ssh2->waitfor( 'extranet#\s*\z', 2 ) or die "prompt 'password' not found after 2 seconds";

## Concacténation des arguements pour la sauvegarde de l'appliance
$command1 = $command1.$opt_iptftp."/".$opt_sauvegarde;

## Exécution de la commande de suavegarde depuis l'appliance
$ssh2->exec($command1);
$ssh2->close();

## Temporisation pour laisser le temps de la copie du fichier sur le serveur TFTP
sleep $pause;

## Commande permettant de récupérer la taille d'un fichier via la commande stat sur un hôte distant
$chemin_sauvegarde= $chemin_tftp .$opt_sauvegarde;
$telnet2 -> cmd ("cd $chemin_tftp");

## Permet de modifier les droits du fichier de sauvegarde
$telnet2 -> cmd ("chmod og+r+w $opt_sauvegarde");

## Commande permettant de récupérer la taille d'un fichier
@line = $telnet2 -> cmd ("stat -c%s $chemin_sauvegarde");
my $taille = @line[0]/1000;

## Autre Test vérifiant la taille du fichier sauvegardé
if ($taille > 0) 
{
$status = 'OK';
$output = " Last Backup Config : " . $date_format .  " - Fichier : " . $opt_sauvegarde . " - Taille : " . $taille . " Ko";
}
else
{
$status = 'CRITICAL';
$output = " Backup Config Error (Taille fichier null) : " . $date_format .  " - Fichier : " . $opt_sauvegarde . " - Taille : " . $taille . " Ko";
}

## Affichage du résultat dans Centreon
printf "$status %s \n", $output;
exit $ERRORS{$status};
