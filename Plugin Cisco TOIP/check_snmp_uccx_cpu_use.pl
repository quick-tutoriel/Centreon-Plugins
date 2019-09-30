#!/usr/bin/perl -w

##
## Plugin init
##
use strict;
use Getopt::Long;
use vars qw($opt_h $opt_community $opt_version $opt_host $opt_w $opt_c);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Net::SNMP;

#Déclaratin des variables
my $result_cpu_use = 0;
my $arrondi_cpu_use;
my $somme_pourcentage_cpu =0;
my $i =0;
my $status = 'OK';

#
## Plugin var init
##
Getopt::Long::Configure('bundling');
GetOptions
("h"	=>	\$opt_h,		"help"		=> \$opt_h,
 "C=s"	=>	\$opt_community,	"community=s"	=> \$opt_community,
 "V=s"  =>	\$opt_version,		"version=s"	=> \$opt_version, 
 "H=s"	=>	\$opt_host,		"host=s"	=> \$opt_host,
 "w=s"	=>	\$opt_w,		"warning=s"	=> \$opt_w,
 "c=s"	=>	\$opt_c,		"critical=s"	=> \$opt_c
);

if ($opt_h){
  print "Usage du plugin :\n";
  print "-h (--help) 		Affiche l'aide\n";
  print "-C (--community)	Valeur de la communaute\n";
  print "-V (--version)		SNMP Version (1-2C-3)\n";
  print "-H (--hostname)	Adresse IP de l'host\n";
  print "-w (--warning) 	Valeur Warning\n";
  print "-c (--critical)	Valeur Critical\n";
  exit ($ERRORS{'UNKNOWN'});
}

if (!defined($opt_community)){
   print "Vous devez saisir une communaute\n";
   exit ($ERRORS{'UNKNOWN'});
}
elsif (!defined($opt_version)){
   print "Vous devez saisir la version de SNMP\n";
   exit ($ERRORS{'UNKNOWN'});
}
elsif (!defined($opt_host)){
   print "Vous devez saisir une adresse ip pour le host\n";
   exit ($ERRORS{'UNKNOWN'});
}
elsif (!defined($opt_w)){
   print "Vous devez saisir une valeur pour WARNING\n";
   exit ($ERRORS{'UNKNOWN'});
}
elsif (!defined($opt_c)){
   print "Vous devez saisir une valeur pour CRITICAL\n";
   exit ($ERRORS{'UNKNOWN'});
}

##
## Initialisation connexion SNMP sur un hôte
my ($session, $error) = Net::SNMP ->session(-community => $opt_community,
					    -version => $opt_version,
					    -hostname => $opt_host,
					    );
if (!defined($session)){
  print ("UNKNOWN: $error\n");
  exit ($ERRORS{'UNKNOWN'});
}

##
## OID permettant de récupérer le pourcentage d'utilisation des coeurs CPU de UCCX
## MIB: HOST-RESOURCES-MIB - TABLEAU: hrProcessorLoad
##
my $snmp_oid_cpu_use = ".1.3.6.1.2.1.25.3.3.1.2";

##
## Permet d'interroger le tableau qui contient la valeur
##
my $resultOID = $session->get_table( -baseoid => $snmp_oid_cpu_use);
if (!defined($resultOID)) {
	printf("UNKNOWN: %s.\n", $session->error);
	$session->close;
	exit $ERRORS{'UNKNOWN'};
}

## recherche dans le tableau la valeur qui correspond à OID de la variable $snmp_oid_system_status
foreach my $key ( sort(keys %$resultOID)) {

#printf ("OID : $key, Desc : $$resultOID{$key}\n");
#Calcul la somme d'utilisation des 4 coeurs
$result_cpu_use = $result_cpu_use + $$resultOID{$key};

#Calcul du nombre de coeurs sur la machine
$i = $i + 1;

}

#Calcul de la moyenne d'utilisation de la CPU de l'UCCX
$result_cpu_use = ($result_cpu_use / $i);
#Arrondir le résultat de la CPU
$arrondi_cpu_use = sprintf("%.0f", $result_cpu_use);

##
## Construction des messages a afficher dans Centreon 
my $output = "CPU used : $arrondi_cpu_use% (Seuils W:$opt_w C:$opt_c)";
my $perfdata = "CPU-Used-Uccx=$arrondi_cpu_use%;$opt_w;$opt_c;0;100";

##
## Test des conditions pour attribuer le status CRITICAL ou WARNING
##
if ( $arrondi_cpu_use >= $opt_c ) {
     $status = 'CRITICAL';
}
elsif ($arrondi_cpu_use >= $opt_w && $arrondi_cpu_use < $opt_c){
      $status = 'WARNING';
}

#Affichage du résultat avec le statut du service dans Centreon
printf "$status %s | %s \n", $output, $perfdata;
exit $ERRORS{$status};
