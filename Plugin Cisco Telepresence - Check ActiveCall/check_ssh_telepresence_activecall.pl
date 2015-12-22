#!/usr/bin/perl 
## Definition des variables et des fonctions à utiliser. 
## Fonction à  rajouter depuis le CPAN, pour effectuer une sauvegarde du commutateur avec PERL
##
use strict;
use Getopt::Long;
use Net::SSH::Expect;
use Net::SNMP;
use vars qw($opt_h $opt_host $opt_command $opt_user $opt_password $opt_w $opt_c);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);

## Initialisation des variables
## Login mot de passe pour connexion direct sans saisir mot de passe dans le script
my $username;
my $password;
## Autres variables
my $output = "";
my $perfdata;
my $status = "UNKNOWN";
my $prompt = '/.*[\$#:>\]\%] *$/';
my @tab;
my $activecalls;
my $line;
my $i;
##
## Initialisation des valeurs de Retour à OK par défaut
##
my $status = 'OK';
## Recherche de la chaine de caracteres dans le retour 
my $searchstring = "NumberOfActiveCalls:";

## Plugin var init
Getopt::Long::Configure('bundling');
GetOptions
("h"	=>	\$opt_h,	"help"		=> \$opt_h,
 "H=s"  =>	\$opt_host,	"host=s"	=> \$opt_host,
 "k=s"	=>	\$opt_command,	"command=s"	=> \$opt_command,
 "w=s"	=>	\$opt_w,	"warning=s"	=> \$opt_w,
 "c=s"	=>	\$opt_c,	"critical=s"	=> \$opt_c,
 "u=s"  =>  \$opt_user,  	"user=s"  	=> \$opt_user,
 "p=s"  =>  \$opt_password, "password=s"  	=> \$opt_password
);

## Affiche l'aide pour exécuter le plugin avec le paramètre -h
## et vérifie si tous les arguments obligatoires sont saisis
if ($opt_h){
  print "Usage du plugin :\n";
  print "-h (--help) 		Affiche l'aide\n";
  print "-H (--host)		Adresse IP\n";
  print "-c (--command)        	Commande\n";
  print "-w (--warning) 	        Valeur Warning nombre d'appel\n";

  print "-c (--critical)	        Valeur Critical nombre d'appel\n";
  print "-u (--user)        	User SSH\n";
  print "-p (--password)       	Password SSH\n";
  exit ($ERRORS{'UNKNOWN'});
}

if (!defined($opt_host)){
   print "Vous devez saisir l'adresse IP de l'equipement\n";
   exit ($ERRORS{'UNKNOWN'});
}
if (!defined($opt_command)){
   print "Veuillez saisir une commande\n";
   exit ($ERRORS{'UNKNOWN'});
}
if (!defined($opt_w)){

   print "Vous devez saisir une valeur pour WARNING\n";   
   exit ($ERRORS{'UNKNOWN'});

}

if (!defined($opt_c)){

   print "Vous devez saisir une valeur pour CRITICAL\n";

   exit ($ERRORS{'UNKNOWN'});
}
if (!defined($opt_user)){
   $opt_user="";
}
if (!defined($opt_password)){
   $opt_password="";
}

## Connexion en SSH sur l'equipement avec le module CPAN Net::SSH:Expect
my $ssh = Net::SSH::Expect->new(
  host     => $opt_host,
  user     => $opt_user,
  password => $opt_password,
  timeout  => 10,
  raw_pty  => 1
);

## Connexion en SSH sur l'equipement
my $login_output = $ssh->login();

## Exécution de la commande sur l'equipement
$ssh->send($opt_command);

## Parcourt le resultat de la commande 
while ( defined ($line = $ssh->read_line()) ) {
     if($line =~m/$searchstring/){
     # Pour chaque ligne de resultat, on verifie si on trouve le mot dans la variable searchstring.
     # Cette variable est a definir en fonction des commandes executees.
     # le caractère espace permet de séparer les mots. Si une correspondance est trouvee on met la ligne sous forme de tableau pour récupérer la valeur voulue.
     @tab=split(" ",$line);
     # On recupere le contenu de la colonne 4 de notre ligne qui correspond
     # au nombre d'appel en cours sur la visio.
     $activecalls = $tab[4];
  }
}

## Test de la valeur $activecalls, pour decider de la valeur du statut du service
if ($activecalls >= $opt_c) {

       $status = 'CRITICAL';

      }

	elsif ($activecalls >= $opt_w && $activecalls < $opt_c) {

          $status = 'WARNING';
      }

## On ferme la connexion sur l'equipement  
$ssh->close();

## Affichage du message de sortie dans Centreon
printf("$status Active Calls : %d (Seuils W:$opt_w C:$opt_c)|Active_Calls=%d\n", $activecalls, $activecalls);

## Fin et sortie du script
exit $ERRORS{$status}; 

