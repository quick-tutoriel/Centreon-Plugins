#!/usr/bin/perl 
## Definition des variables et des fonctions à utiliser. 
use strict;
use Getopt::Long;
use Net::SSH::Expect;
use Net::SNMP;
use vars qw($opt_h $opt_host $opt_command $opt_low_limit $opt_upper_limit $opt_user $opt_password $opt_interface);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);

## Initialisation des variables
my $output = "";
my $status = "OK";
my $perfdata = "";
my $prompt = '/.*[\$#:>\]\%] *$/';
my $stdout="";
my $line;
my $x = 0;
my $i = 0;
my @line;
my @attenuation;


## Plugin var init
Getopt::Long::Configure('bundling');
GetOptions
("h"	=>	\$opt_h,	"help"		=> \$opt_h,
 "H=s"  =>	\$opt_host,	"host=s"	=> \$opt_host,
 "C=s"	=>	\$opt_command,	"command=s"	=> \$opt_command,
 "L=s"	=>	\$opt_low_limit, "lowlimit=s"	=> \$opt_low_limit,
 "U=s"	=>	\$opt_upper_limit, "upperlimit=s" => \$opt_upper_limit,
 "I=s"	=>	\$opt_interface, "interface=s" => \$opt_interface,
 "u=s"  =>      \$opt_user,  	"user=s"  	=> \$opt_user,
 "p=s"  =>      \$opt_password, "password=s"  	=> \$opt_password
);


## Affiche l'aide pour exécuter le plugin avec le paramètre -h
## et vérifie si tous les arguments obligatoires sont saisis
if ($opt_h){
  print "Usage du plugin :\n";
  print "-h (--help) 		Affiche l'aide\n";
  print "-H (--host)		Adresse IP\n";
  print "-C (--command)        	Commande\n";
  print "-I (--interface)      	Indiquer le type d'interface Te ou Gi\n";
  print "-L (--lowerlimit) 	Valeur lower limit en dBm \n";
  print "-U (--upperlimit)	Valeur upper limit en dBm\n";
  print "-K (--user)        	User SSH\n";
  print "-P (--password)       	Password SSH\n";
  exit ($ERRORS{'UNKNOWN'});
}

if (!defined($opt_host)){
   print "Vous devez saisir l'adresse IP du switch\n";
   exit ($ERRORS{'UNKNOWN'});
}
if (!defined($opt_interface)){
   print "Veuillez saisir un type d'interface Te ou Gi\n";
   exit ($ERRORS{'UNKNOWN'});
}
if (!defined($opt_command)){
   print "Veuillez saisir une commande\n";
   exit ($ERRORS{'UNKNOWN'});
}
if (!defined($opt_low_limit)){
   print "Vous devez saisir une valeur low limit\n";
   exit ($ERRORS{'UNKNOWN'});
}
if (!defined($opt_upper_limit)){
   print "Vous devez saisir une valeur upper limit\n";
   exit ($ERRORS{'UNKNOWN'});
}
## On peut forcer ici le mot de passe pour éviter de le saisir
## en ligne de commande
if (!defined($opt_user)){
   $opt_user="";
}
if (!defined($opt_password)){
   $opt_password="";
}


## Passage des paramtres de connexion :
## l'adresse IP, le user et le password de l'équipement
my $ssh = Net::SSH::Expect->new(
  host     => $opt_host,
  user     => $opt_user,
  password => $opt_password,
  timeout  => 15,
  raw_pty  => 1
);

##Connexion SSH ˆ l'équipement
my $login_output = $ssh->login();

## Exécution de la commande sur le switch
## Using send() instead of exec()
$ssh->send($opt_command);  

## Toutes les lignes retournées par la commande sont parcourues grâce à la boucle While
## Puis ensuite chaque mot de la ligne est mis dans le tableau @tab.
## Le caractère de séparation étant un espace.
while ( defined ($line= $ssh->read_line()) ) {
     my @tab=split(" ",$line);
     ## On parcourt le résultat de la commande jusqu'à trouver la valeur saisie en paramètre
     ## concernant le début de l'interface Te (pour les ports en 10 Gb) ou Gi (pour les ports en Gigabits)     
       if($tab[0]=~m/$opt_interface/){
         ## Une fois arrivée à la ligne commençant par Gi ou Te
         ## on lit les différents "mots" de la ligne pour trouver la valeur qui nous convient"
         ## ici on veut récupérer l'atténuation du Gbic, la colonne s'appelle Rx Power (dbm)
          for $i (0..$#tab) {
           ## Dans certains résultats de commande on peut avoir des paramètres supplémentaires
           ## comme - ou -- ou + ou ++ qui indiquent généralement une alarme. On ne mets dans notre tableau
           ## uniquement les valeurs en chiffre           
           if ( ($tab[$i] != "+") || ($tab[$i] != "-") || ($tab[$i] != "++") || ($tab[$i] != "--"))
           {
             $attenuation[$x]=$tab[$i];
             $x = $x + 1;
           }         
          }    
       
       # La valeur qui nous intéresse se trouve à la fin de notre tableau 
       $stdout=$attenuation[-1];
      
       }
       
}

## Ferme la connexion SSH sur l'équipement
$ssh->close();

## Vérifie si la variable $stdout contient une valeur, si non sort du programme avec le Statut CRITIQUE
if (not($stdout)){
   $status = "CRITICAL";
   $output = "Impossible de recuperer l'attenuation du module.";
   print "$status $output\n";
   exit $ERRORS{$status}; 
}

## Test de l'atténuation du port
if ($stdout >= $opt_low_limit && $stdout <= $opt_upper_limit)
{
       $status = "OK";
       $perfdata = "Attenuation=$stdout";
       $output ="Attenuation correcte. Attenuation : $stdout Dbm (Low Limit : $opt_low_limit, Upper Limit : $opt_upper_limit)";
}else
{
       $status = "CRITICAL";
       $perfdata = "Attenuation=$stdout";
       $output ="Degradation de l'attenuation. Attenuation : $stdout Dbm (Low Limit : $opt_low_limit, Upper Limit : $opt_upper_limit)";
}

## Affichage des informations dans Centreon
printf "$status %s | %s \n", $output, $perfdata;
exit $ERRORS{$status}; 
