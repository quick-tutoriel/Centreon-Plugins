#!/usr/bin/perl -w

# Script:       check_snmp_wism_ha.pl
# Version:      1
# Date:			10/10/2014
# Author:       Guillaume REYNAUD <webmaster@quick-tutoriel.com>
# Description:  Checks HA Wism with snmp

##
## Plugin init
##
use strict;
use Getopt::Long;
use vars qw($opt_h $opt_community $opt_version $opt_host);
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
## Description de votre OID
##
my $snmp_oid = ".1.3.6.1.4.1.9.9.198888.0.1.12.0";


##
## Permet de faire un get sur une feuille (OID)
##
my $resultOID = $session->get_request(-varbindlist => [$snmp_oid]);
if (!defined($resultOID)) {
	printf("UNKNOWN: %s.\n", $session->error);
	$session->close;
	exit $ERRORS{'UNKNOWN'};
}

##
## Récupération de la valeur de OID
##
my $result = $resultOID->{$snmp_oid};

##
## Déclaration d'une variable pour récupérer le statut, pour l'afficher dans la sortie. Par défaut OK
##
my $status = 'OK';
my $output = '';


##
## Test des conditions pour attribuer le status CRITICAL ou WARNING
## On récupère la valeur de OID clHAPrimaryUnit de la MIB CISCO-LWAPP-HA
## 1: Fonctionnement normal du cluster, 2: Bascule du cluster sur la carte WISM de backup
##
if ( $result == 1 ) {
       $output ="CLuster WISM OK - HA Primary Unit : Active - Secondary Unit : Inactive";
      }
	elsif ( $result == 2 ){
         $output ="Cluster WISM Fail - HA Primary Unit : Inactive - Secondary Unit : Active";  
         $status = 'CRITICAL';
      }
  
#Affichage des résultats dans Centreon
printf "$status %s\n", $output;
exit $ERRORS{$status};

