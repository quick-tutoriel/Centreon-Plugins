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


##
## Plugin var init
##
Getopt::Long::Configure('bundling');

GetOptions

("h"	=>	\$opt_h,		"help"		=> \$opt_h,

 "C=s"	=>	\$opt_community,	"community=s"	=> \$opt_community,

 "V=s"  =>	\$opt_version,		"version=s"	=> \$opt_version, 

 "H=s"	=>	\$opt_host,		"host=s"	=> \$opt_host);



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
## Recuperation du statut des batteries des onduleurs dans la MIB Specifique powernet416.mib
## upsBasicBatteryStatus
##

my $snmp_oid_current_status = ".1.3.6.1.4.1.318.1.1.1.2.1.1.0";


##
## Permet de faire un get sur une feuille (OID) pour récupérer la valeur de l'OID
##
my $resultOID = $session->get_request(-varbindlist => [$snmp_oid_current_status]);
if (!defined($resultOID)) {
	printf("UNKNOWN: %s.\n", $session->error);
	$session->close;
	exit $ERRORS{'UNKNOWN'};
}

##
## Récupération de la valeur de OID
## 1= unknown 2 = Normal, 3= BatteryLow, 4= batteryInFaultCondition
##
my $result = $resultOID->{$snmp_oid_current_status};

##
## Déclaration d'une variable pour récupérer le statut, pour l'afficher dans la sortie. Par défaut OK
##
my $status = 'OK';
my $output = "";

##
## Test des conditions pour attribuer le status CRITICAL ou WARNING
##
if ($result  == 1) {
   $status = 'UNKNOWN'; 
   $output = "Status Battery : Unknown";
} elsif ($result  == 2) {
   $status = 'OK'; 
   $output = "Status Battery : Ok";
} elsif ($result  == 3) {
   $status = 'WARNING'; 
   $output = "Status Battery : Low";
} elsif ($result  == 4) {
   $status = 'WARNING'; 
   $output = "Status Battery : Fault";
}
 else {
   $status = 'UNKNOWN'; 
   $output = "Status Battery : Unknown";
}

##
## Affichage du résultat dans Centreon
printf "$status %s \n", $output;
exit $ERRORS{$status};