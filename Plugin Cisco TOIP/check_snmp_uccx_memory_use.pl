#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use vars qw($opt_h $opt_community $opt_version $opt_host $opt_w $opt_c);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Net::SNMP;

#Declarations des variables
my $perfdata = "";
my $status = 'OK';
my $output = "";
my $i = 0;
my $Storage_AllocationUnits = 0;
my $Storage_AllocationUnits_session ;
my $Result_Storage_AllocationUnits;
my $Storage_Size = 0;
my $Storage_Size_session;
my $Result_Storage_Size;
my $Storage_Used = 0;
my $Storage_Used_session;
my $Result_Storage_Used;
my $Physical_Memory_Used = 0;
my $Physical_Memory_Used_Real = 0;
my $Storage_Size_virtual = 0;
my $Storage_Size_session_virtual = 0;
my $Result_Storage_Size_virtual = 0;
my $Storage_Size_Used_virtual = 0;
my $Storage_Size_Used_session_virtual = 0;
my $Result_Storage_Size_Used_virtual = 0;
my $Total_Memory = 0;
my $Total_Memory_Used = 0;

Getopt::Long::Configure('bundling');
GetOptions
("h"	=>	\$opt_h,		"help"		=> \$opt_h,
 "C=s"	=>	\$opt_community,	"community=s"	=> \$opt_community,
 "V=s"  =>	\$opt_version,		"version=s"	=> \$opt_version, 
 "H=s"	=>	\$opt_host,		"host=s"	=> \$opt_host,
 "w=s"	=>	\$opt_w,		"warning=s"	=> \$opt_w,
 "c=s"	=>	\$opt_c,		"critical=s"	=> \$opt_c);

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

#verification des arguments rentres en parametres
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

#Initialisation de la connexion SNMP sur le poste Windows
my ($session, $error) = Net::SNMP ->session(-community => $opt_community,
					    -version => $opt_version,
					    -hostname => $opt_host,
					    );
if (!defined($session)){
  print ("UNKNOWN: $error\n");
  exit ($ERRORS{'UNKNOWN'});
}

#OID permettant de recuperer l'utilisation de la RAM Physique d'une VM UCCX, dans la MIB HOST-RESOURCES-MIB
my $snmp_oid= ".1.3.6.1.2.1.25.2.3.1.3";

my $resultOID = $session->get_table( -baseoid => $snmp_oid);
if (!defined($resultOID)) {
   printf ("UNKNOWN: %s. \n", $session->error);
   $session->close;
   exit ($ERRORS{'UNKNOWN'});
} 

#Récupération des informations sur la Consomamtion RAM de la VM UCCX
#
#Recuperation du StorageAllocationUnits.
$Storage_AllocationUnits = ".1.3.6.1.2.1.25.2.3.1.4.1";
$Storage_AllocationUnits_session = $session->get_request(-varbindlist => [$Storage_AllocationUnits]);
$Result_Storage_AllocationUnits = $Storage_AllocationUnits_session->{$Storage_AllocationUnits};

#Recuperation du Storage Size Virtual.
$Storage_Size_virtual = ".1.3.6.1.2.1.25.2.3.1.5.2";
$Storage_Size_session_virtual = $session->get_request(-varbindlist => [$Storage_Size_virtual]);
$Result_Storage_Size_virtual = $Storage_Size_session_virtual->{$Storage_Size_virtual};
$Result_Storage_Size_virtual = ($Result_Storage_AllocationUnits * $Result_Storage_Size_virtual) /1024 /1024 /1024;

#Recuperation du Storage Used Virtual.
$Storage_Size_Used_virtual = ".1.3.6.1.2.1.25.2.3.1.6.2";
$Storage_Size_Used_session_virtual = $session->get_request(-varbindlist => [$Storage_Size_Used_virtual]);
$Result_Storage_Size_Used_virtual = $Storage_Size_Used_session_virtual->{$Storage_Size_Used_virtual};
$Result_Storage_Size_Used_virtual = ($Result_Storage_AllocationUnits * $Result_Storage_Size_Used_virtual) /1024 /1024 /1024;

#Recuperation du Storage Size RAM.
$Storage_Size = ".1.3.6.1.2.1.25.2.3.1.5.1";
$Storage_Size_session = $session->get_request(-varbindlist => [$Storage_Size]);
$Result_Storage_Size = $Storage_Size_session->{$Storage_Size};
$Result_Storage_Size = ($Result_Storage_AllocationUnits *$Result_Storage_Size) /1024 /1024 /1024;

#Recuperation du Storage Used RAM.
$Storage_Used = ".1.3.6.1.2.1.25.2.3.1.6.1";
$Storage_Used_session = $session->get_request(-varbindlist => [$Storage_Used]);
$Result_Storage_Used =  $Storage_Used_session->{$Storage_Used};
$Physical_Memory_Used = ($Result_Storage_Used * $Result_Storage_AllocationUnits)/1024 /1024 /1024;

#Calcul de la mémoire totale consommée (RAM + Virtual)
$Total_Memory = $Result_Storage_Size_virtual + $Result_Storage_Size;
$Total_Memory_Used = $Result_Storage_Size_Used_virtual + $Physical_Memory_Used;

#Calcul du % de la mémoire totale utilisée
$Physical_Memory_Used_Real = ($Total_Memory_Used * 100) / $Total_Memory;
$Physical_Memory_Used_Real = sprintf("%.0f",  $Physical_Memory_Used_Real);

#Arrondi de la valeur de la consomation de RAM Totale
$Physical_Memory_Used = sprintf("%.0f",  $Total_Memory_Used);

#Test pour attribuer un statut au service.
if ($Physical_Memory_Used_Real >= $opt_c ) 
{
  $status = 'CRITICAL';
}
elsif (($Physical_Memory_Used_Real >= $opt_w) && ($Physical_Memory_Used_Real < $opt_c ) )
{
  $status = 'WARNING';
}

#Modification de l'affichage et creation des donnees de performance
$output = "Physical Memory Used: $Physical_Memory_Used Gb ($Physical_Memory_Used_Real%) (Seuils W:$opt_w C:$opt_c)";
$perfdata = "Physical_Memory_Used=$Physical_Memory_Used_Real%;$opt_w;$opt_c;0;100";

#Affichage des informations dans Centreon
printf "$status %s|%s \n", $output, $perfdata;
exit $ERRORS{$status};
