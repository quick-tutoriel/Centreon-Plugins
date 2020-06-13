#!/usr/bin/perl 
## Definition les variables et les fonctions a utiliser. 
##
use strict;
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
my $status = "UNKNOWN";
my $prompt = '/.*[\$#:>\]\%] *$/';
my $appareil_poe = "";
my $consomation_poe = "";
my $puissance_totale = "";
my $stdout= "";
my $result = "";
my $status = 'OK';
my $poucentage_util = "";
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


## Connexion en SSH sur Cisco 4500
##
my $ssh = Net::SSH::Expect->new(
  host     => $host,
  user     => $user,
  password => $password,
  timeout  => 15,
  raw_pty  => 1
);

my $login_output = $ssh->login();

## Exécution de la commande sur le switch
## Commande necessaire pour supprimer --MORE-- sur une sortie longue
##
$ssh->exec("terminal length 0");
$ssh->send($command);   # using send() instead of exec()

## Parcourt toutes les lignes du retour de la commande
##
while ( defined ($line= $ssh->read_line()) ) {
    #Ligne permettant de récupérer la puissance totale de l'alimentation du switch
    ##
    if($line=~m/Available:/){
	$line=~ s/[a-z]|[:]|[()]//gi;
        my @tab=split(" ",$line);
        $puissance_totale = sprintf("%.0f", $tab[0]);
    }   
    
    #Ligne permettant de récuérer le nombre d'appareil POE connecté au switch et la consommation POE totale sur le switch
    ##
    if($line=~m/Totals:/){
        $line=~ s/[a-z]|[:]//gi;
        my @tab=split(" ",$line);  
        $appareil_poe = $tab[0];
        $consomation_poe = sprintf("%.0f", $tab[1]);
    }
}

## Reactivation de la sortie par defaut
##
$ssh->exec("terminal length 24");
## Ferme la connexion SSH sur l'équipement
##
$ssh->close();

## Calcul poucentage d'utilisation du POE sur le switch
##
$poucentage_util = (100 * $consomation_poe)/$puissance_totale;
## On arrondi le pourcentage pour faire des valeurs plus lisibles
$poucentage_util = sprintf("%.0f", $poucentage_util);

## Test des conditions pour attribuer le status CRITICAL ou WARNING ou service
##
if ( $result >= $opt_c ) {

       $status = 'CRITICAL';
      }

	elsif ($result >= $opt_w && $result < $opt_c){

           $status = 'WARNING';

      }

## Construction de l'affichage pour Centreon
$perfdata = "CONSUMEDPOWER=$consomation_poe, AVAILABLEPOWER=$puissance_totale";
$output = "Devices Connected POE : $appareil_poe - Available Power (Watts) : $puissance_totale - Consumed Power (Watts) : $consomation_poe ($poucentage_util% used) (Seuils W:$opt_w C:$opt_c)";

#Affichage des résultats dans Centreon

printf "$status %s|%s \n", $output, $perfdata;

exit $ERRORS{$status};
