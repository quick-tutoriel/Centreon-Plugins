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
my $status = 'OK';
my $total_phones = 0;
my $pourcentage_registered_phones = 0;
my $pourcentage_unregistered_phones = 0;
my $pourcentage_rejected_phones = 0;

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
  print "-w (--warning) 	Valeur Warning pour le pourcentage autorisé de TEL Unregistered ou Rejected\n";
  print "-c (--critical)	Valeur Critical pour le pourcentage autorisé de TEL Unregistered ou Rejected\\n";
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
## OID permettant de récupérer le statut des téléphones REGISTERED UNREGISTERED REJECTED
## MIB: CISCO-CCM-MIB - TABLEAU: ccmGlobalInfo
##
my $snmp_oid_registered_phones = ".1.3.6.1.4.1.9.9.156.1.5.5.0";
my $snmp_oid_unregistered_phones = ".1.3.6.1.4.1.9.9.156.1.5.6.0";
my $snmp_oid_rejected_phones = ".1.3.6.1.4.1.9.9.156.1.5.7.0";

##
## Permet d'interroger le tableau qui contient la valeur
##
my $resultOID = $session->get_request(-varbindlist => [$snmp_oid_registered_phones,$snmp_oid_unregistered_phones,$snmp_oid_rejected_phones]);
if (!defined($resultOID)) {
	printf("UNKNOWN: %s.\n", $session->error);
	$session->close;
	exit $ERRORS{'UNKNOWN'};
}


##
## Récupération des valeurs des OID
##
my $result_registered_phones = $resultOID->{$snmp_oid_registered_phones};
my $result_unregistered_phones = $resultOID->{$snmp_oid_unregistered_phones};
my $result_rejected_phones = $resultOID->{$snmp_oid_rejected_phones};


##
## Nombre de téléphones provisionnés sur le CUCM
##
$total_phones = $result_registered_phones + $result_unregistered_phones + $result_rejected_phones;

## 
## calcul pourcentages statuts telephones
##
$pourcentage_registered_phones = ($result_registered_phones*100)/$total_phones;
$pourcentage_registered_phones = sprintf("%.0f",$pourcentage_registered_phones);

$pourcentage_unregistered_phones = ($result_unregistered_phones*100)/$total_phones;
$pourcentage_unregistered_phones = sprintf("%.0f",$pourcentage_unregistered_phones);

$pourcentage_rejected_phones = ($result_rejected_phones*100)/$total_phones;
$pourcentage_rejected_phones = sprintf("%.0f",$pourcentage_rejected_phones);

##
## Attribution d'un statut au check du service
##
if ($total_phones==0) {

  $status='CRITICAL';

} if (($pourcentage_unregistered_phones > $opt_c) || ($pourcentage_rejected_phones > $opt_c)) {
   
    $status='CRITICAL';

} if ((($pourcentage_unregistered_phones >= $opt_w) && ($pourcentage_unregistered_phones < $opt_c )) || (($pourcentage_rejected_phones >= $opt_w) && ($pourcentage_rejected_phones < $opt_c ))) {
  
   $status='WARNING';
}

##
## Construction des messages a afficher dans Centreon 
##
my $output = "Registered : $pourcentage_registered_phones% ($result_registered_phones Phones) - Unregistered : $pourcentage_unregistered_phones% ($result_unregistered_phones Phones) - Rejected : $pourcentage_rejected_phones% ($result_rejected_phones Phones) (Seuils W:$opt_w C:$opt_c)";
my $perfdata = "Registered-Phones=$pourcentage_registered_phones%;$opt_w;$opt_c;0;100,UnRegistered-Phones=$pourcentage_unregistered_phones%;$opt_w;$opt_c;0;100,Rejected-Phones=$pourcentage_rejected_phones%;$opt_w;$opt_c;0;100";

##
##Affichage du résultat avec le statut du service dans Centreon
##
printf "$status %s | %s \n", $output, $perfdata;
exit $ERRORS{$status};

