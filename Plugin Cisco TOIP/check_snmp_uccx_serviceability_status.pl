#!/usr/bin/perl -w

##
## Plugin init
##
use strict;
use Getopt::Long;
use vars qw($opt_h $opt_community $opt_version $opt_host);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Net::SNMP;

#Déclaratin des variables
my $result_system_status;
my $descr_system_status;
my $status = 'OK';

#
## Plugin var init
##
Getopt::Long::Configure('bundling');
GetOptions
("h"	=>	\$opt_h,		"help"		=> \$opt_h,
 "C=s"	=>	\$opt_community,	"community=s"	=> \$opt_community,
 "V=s"  =>	\$opt_version,		"version=s"	=> \$opt_version, 
 "H=s"	=>	\$opt_host,		"host=s"	=> \$opt_host
);

if ($opt_h){
  print "Usage du plugin :\n";
  print "-h (--help) 		Affiche l'aide\n";
  print "-C (--community)	Valeur de la communaute\n";
  print "-V (--version)		SNMP Version (1-2C-3)\n";
  print "-H (--hostname)	Adresse IP de l'host\n";
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
## OID permettant de récupérer le statut de UCCX
## MIB: CISCO-CUICAPPS-MIB - TABLEAU: cuicGeneralInfoSystemStatus
##
my $snmp_oid_system_status = ".1.3.6.1.4.1.9.9.718.1.1.1.7";

##
## Permet d'interroger le tableau qui contient la valeur
##
my $resultOID = $session->get_table( -baseoid => $snmp_oid_system_status);
if (!defined($resultOID)) {
	printf("UNKNOWN: %s.\n", $session->error);
	$session->close;
	exit $ERRORS{'UNKNOWN'};
}

## recherche dans le tableau la valeur qui correspond à OID de la variable $snmp_oid_system_status
foreach my $key ( sort(keys %$resultOID)) {

#printf ("OID : $key, Desc : $$resultOID{$key}\n");
 
$result_system_status = $$resultOID{$key};

if ($result_system_status == 1) {
  $descr_system_status = "InService";
} 
  elsif ($result_system_status == 2) {
  $descr_system_status = "PartialService";
} 
  elsif ($result_system_status == 3) {
  $descr_system_status = "NotResponding";
} 
  elsif ($result_system_status == 4) {
  $descr_system_status = "Unknown";
} 
  else {
  $descr_system_status = "Unknown";
}		
}

##
## Construction des messages a afficher dans Centreon 
my $output = "Service Status UCCX : $descr_system_status";

##
## Test des conditions pour attribuer le status CRITICAL ou WARNING
##
if ( $result_system_status == 1 ) {
       $status = 'OK';
   }
elsif ( $result_system_status == 2 ) {
       $status = 'WARNING';
}
elsif ( $result_system_status >= 3 ) {
       $status = 'CRITICAL';
}

#Affichage du résultat avec le statut du service dans Centreon
printf "$status %s\n", $output;
exit $ERRORS{$status};



