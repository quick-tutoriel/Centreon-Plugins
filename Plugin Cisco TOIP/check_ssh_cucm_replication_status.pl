#!/usr/bin/perl 
## Definition des variables et des fonctions à utiliser. 
## Fonction à  rajouter depuis le CPAN, pour effectuer une sauvegarde du commutateur avec PERL
##
use strict;
use warnings;
use Getopt::Long;
use Net::SSH::Expect;
use Net::SNMP;
use vars qw($opt_h $opt_host $opt_command $opt_user $opt_password);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);

## Autres variables
##
my $output = "";
my $perfdata = "";
my $replicate_state = "";
my $label_replicate_state = "";
my $offset = "";
my $status = 'OK';
my $line;
my @tab;

## Plugin var init
##
Getopt::Long::Configure('bundling');
GetOptions
("h"	=>	\$opt_h,	"help"		=> \$opt_h,
 "H=s"  =>	\$opt_host,	"host=s"	=> \$opt_host,
 "k=s"	=>	\$opt_command,	"command=s"	=> \$opt_command,
 "u=s"  =>      \$opt_user,  	"user=s"  	=> \$opt_user,
 "p=s"  =>      \$opt_password, "password=s"  	=> \$opt_password
);


## Affiche l'aide pour exécuter le plugin avec le paramètre -h
## et vérifie si tous les arguments obligatoires sont saisis
##
if ($opt_h){
  print "Usage du plugin :\n";
  print "-h (--help) 		Affiche l'aide\n";
  print "-H (--host)		Adresse IP du switch\n";
  print "-k (--command)        	Commande a executer sur le CUCM\n";
  print "-u (--user)        	User SSH\n";
  print "-p (--password)       	Password SSH\n";
  exit ($ERRORS{'UNKNOWN'});
}

if (!defined($opt_host)){
   print "Vous devez saisir l'adresse IP du switch\n";
   exit ($ERRORS{'UNKNOWN'});
}
if (!defined($opt_command)){
   print "Veuillez saisir une commande\n";
   exit ($ERRORS{'UNKNOWN'});
}
if (!defined($opt_user)){
   $opt_user="";
}
if (!defined($opt_password)){
   $opt_password="";
}

## Affectation des options saisies dans des variables
##
my $command=$opt_command;
my $host=$opt_host;
my $user=$opt_user;
my $password=$opt_password;


## Connexion en SSH sur le CUCM
##
my $ssh = Net::SSH::Expect->new(
  host     => $host,
  user     => $user,
  password => $password,
  timeout  => 15,
  raw_pty  => 1
);

my $login_output = $ssh->login();

if ($login_output !~ /admin:/) {
    die "Login has failed. Login output was $login_output";
} 

## Execute la commande sur le CUCM
##
$ssh->send($command);   

## Parcours toutes les lignes du retour de la commande
##
while ( defined ($line= $ssh->read_line()) ) {
      
     #printf ("$line\n");
     #Ligne permettant de récupérer si l'horloge est synchronisée
     if($line=~m/Replicate_State/){
	#$line=~ s/[a-z]|[:]|[()]//gi;
        my @tab=split(" ",$line);
        $replicate_state = $tab[4];
     }             
}

## Associe le numéro à un libellé compréhensible par tous les utilisateurs
##
if ($replicate_state == 2) {
           $status = 'OK';
           $label_replicate_state = "Replication is good";

} elsif ($replicate_state == 0) {
           $status = 'WARNING';
           $label_replicate_state = "Initialization State"

} elsif ($replicate_state == 1) {
           $status = 'WARNING';
           $label_replicate_state = "Number of Replicates not correct"

} elsif ($replicate_state == 3) {
           $status = 'WARNING';
           $label_replicate_state = "Tables are suspect"

} elsif ($replicate_state == 4) {
           $status = 'CRITICAL';
           $label_replicate_state = "Setup Failed / Dropped"
}                
    
## Construction de l'affichage pour Centreon
$output = "Replication State : $label_replicate_state";

## Ferme la connexion SSH sur le CUCM
##
$ssh->close();

#Affichage des résultats dans Centreon
printf "$status %s\n", $output;
exit $ERRORS{$status};


