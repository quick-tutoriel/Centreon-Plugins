#!/usr/bin/perl 
## Definition des variables et des fonctions à utiliser. 
## Fonction à  rajouter depuis le CPAN, pour effectuer une sauvegarde du commutateur avec PERL
##
use strict;
use warnings;
use Getopt::Long;
use Net::SSH::Expect;
use Net::SNMP;
use vars qw($opt_h $opt_host $opt_command $opt_w $opt_c $opt_user $opt_password);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);

## Autres variables
##
my $output = "";
my $perfdata = "";
my $call_in_progress = "";
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
 "w=s"	=>	\$opt_w,	"warning=s"	=> \$opt_w,
 "c=s"	=>	\$opt_c,	"critical=s"	=> \$opt_c,
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
  print "-k (--command)        	Commande a executer sur le switch\n";
  print "-w (--warning) 	        Valeur Warning\n";
  print "-c (--critical)	        Valeur Critical\n";
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

     #Ligne permettant de récupérer si l'horloge est synchronisée
     if($line=~m/-> CallsInProgress/){
	#$line=~ s/[a-z]|[:]|[()]//gi;
        my @tab=split(" ",$line);
        $call_in_progress = $tab[3];
     }          
}


## Test des conditions pour attribuer le status CRITICAL ou WARNING ou service
##
if (($call_in_progress == "0") || ($call_in_progress >= $opt_c)) {
           $status = 'CRITICAL';
           $output = "Calls In Progress : $call_in_progress (Seuils W:$opt_w C:$opt_c)";

      }
	elsif ($call_in_progress >= $opt_w && $call_in_progress < $opt_c){
           $status = 'WARNING';
           $output = "Calls In Progress : $call_in_progress (Seuils W:$opt_w C:$opt_c)";
      } else {
           $status = 'OK';
           $output = "Calls In Progress : $call_in_progress (Seuils W:$opt_w C:$opt_c)";     
      }

## Construction de l'affichage pour Centreon
$perfdata = "CALLINPROGRESS=$call_in_progress;$opt_w;$opt_c";

## Ferme la connexion SSH sur le CUCM
##
$ssh->close();

#Affichage des résultats dans Centreon
printf "$status %s|%s \n", $output, $perfdata;
exit $ERRORS{$status};

