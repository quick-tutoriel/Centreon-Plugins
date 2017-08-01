#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use vars qw($opt_h $opt_community $opt_version $opt_host);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Net::SNMP;

#Déclaration des variables
my $index;
my $Process_Name;
my $Session_Process_Name;
my $Result_Process_Name;
my $Process_Color;
my $Session_Process_Color;
my $Result_Process_Color;
my $compteurcritical = 0;
my $compteurwarning = 0;
my $outputcritical;
my $outputwarning;
my $output;
my $status = "OK";


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


my ($session, $error) = Net::SNMP ->session(-community => $opt_community,
					    -version => $opt_version,
					    -hostname => $opt_host,
					    );
if (!defined($session)){
  print ("UNKNOWN: $error\n");
  exit ($ERRORS{'UNKNOWN'});
}

#OID se trouvant dans la MIB CISCO-ENTITY-DISPLAY. On affiche le contenu de la table ceDisplayTable qui retourne pour chaque carte du chassis
#l'état du port, du module comme si on était devant le switch.
my $snmp_oid= ".1.3.6.1.4.1.9.9.344.1.1.1.2";

#On parcourt l'ensemble de la table.
my $resultOID = $session->get_table( -baseoid => $snmp_oid);
if (!defined($resultOID)) {
   printf ("UNKNOWN: %s. \n", $session->error);
   $session->close;
   exit ($ERRORS{'UNKNOWN'});
} 


foreach my $key ( sort(keys %$resultOID)) {
  #recupération des 2 dernieres valeur de l'index value
  my @index_value = split /[.]/,$key;
  $index=$index_value[14]. ".".$index_value[15];
  
  #Recuperation du display name (Récupère le nom du module ou du port sur le switch)
  $Process_Name = ".1.3.6.1.4.1.9.9.344.1.1.1.3." . $index;
  $Session_Process_Name = $session->get_request(-varbindlist => [$Process_Name]);
  $Result_Process_Name = $Session_Process_Name->{$Process_Name};
  
  #Recuperation du display color (couleur du module)
  $Process_Color = ".1.3.6.1.4.1.9.9.344.1.1.1.5." . $index;
  $Session_Process_Color = $session->get_request(-varbindlist => [$Process_Color]);
  $Result_Process_Color = $Session_Process_Color->{$Process_Color};
  
  #Récupération des modules défaillant qui ont la LED rouge d'allumée en excluant les ports d'accès du switch.
  if (($Result_Process_Color == 3) && ($Result_Process_Name !~/GigabitEthernet/))  {
      $compteurcritical = $compteurcritical +1;
      $outputcritical = $outputcritical . $Result_Process_Name;
   }

  #Récupération des modules défaillant qui ont la LED orange d'allumée en excluant les ports d'accès du switch.
  if (($Result_Process_Color == 6) && ($Result_Process_Name !~/GigabitEthernet/))  {
      $compteurwarning = $compteurwarning +1;
      $outputwarning = $outputwarning . $Result_Process_Name;
   }

}

#Détermination du statut du service.
if (($compteurcritical == 0) && ($compteurwarning == 0)){
   $status = "OK";
   $output = "All modules are Green LED";
} elsif ($compteurcritical > 0) {
   $status = "CRITICAL";
   $output = "$compteurcritical Modules have Red LED: $outputcritical";
} else {
   $status = "WARNING";
   $output = "$compteurwarning Modules have Amber LED: $outputwarning";
}

#Affichage des informations dans centreon.
printf "$status %s\n", $output;
exit $ERRORS{$status};

