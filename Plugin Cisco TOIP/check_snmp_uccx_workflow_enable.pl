#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use vars qw($opt_h $opt_community $opt_version $opt_host);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Net::SNMP;

#Declarations des variables
my $perfdata = "";
my $status = 'OK';
my $output = "";
my $outputdisable;
my $ApplicationName;
my $Application_Enable;
my $Application_Enable_session;
my $Result_Application_Enable;
my $id;
my $i = 0;
my $Compteur_Enable = 0;
my $Compteur_Disable = 0;


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

#Initialisation de la connexion SNMP sur le poste Windows
my ($session, $error) = Net::SNMP ->session(-community => $opt_community,
					    -version => $opt_version,
					    -hostname => $opt_host,
					    );
if (!defined($session)){
  print ("UNKNOWN: $error\n");
  exit ($ERRORS{'UNKNOWN'});
}

#OID permettant de recuperer le load de chaque core du processeur, dans la MIB HOST-RESOURCES-MIB
my $snmp_oid= ".1.3.6.1.4.1.9.9.190.1.1.1.1";

my $resultOID = $session->get_table( -baseoid => $snmp_oid);
if (!defined($resultOID)) {
   printf ("UNKNOWN: %s. \n", $session->error);
   $session->close;
   exit ($ERRORS{'UNKNOWN'});
} 

#Recuperation de l'utilisation du disque
foreach my $key ( sort(keys %$resultOID)) {

 #Récupération du nom de l'application SVI
 if ($key =~ /1.3.6.1.4.1.9.9.190.1.1.1.1.2./){
   
   #récupération du nom de l'application SVI et de son Numéro d'ID 
   #Récupération de l'ID
   $id = $key;
   $id =  substr $id, 31;
   #Récupération du nom de l'application
   $ApplicationName = $$resultOID{$key};

    if (($ApplicationName !~ /Recette/) && ($ApplicationName !~ /Test/) && ($ApplicationName !~ /TEST/) && ($ApplicationName !~ /Formation/) && ($ApplicationName !~ /Atelier-Dec/))  {
        #Recuperation du statut de l'application Enabled(1) ou Disbaled(2)
        $Application_Enable = ".1.3.6.1.4.1.9.9.190.1.1.1.1.5." . "$id";
        $Application_Enable_session = $session->get_request(-varbindlist => [$Application_Enable]);
        $Result_Application_Enable = $Application_Enable_session->{$Application_Enable};
        #Traduction du statut
        if  ($Result_Application_Enable == 1){
          $Compteur_Enable = $Compteur_Enable + 1;
        } elsif ($Result_Application_Enable == 2) {
          $Compteur_Disable = $Compteur_Disable + 1;
          $outputdisable = $outputdisable . " $ApplicationName"; 
        }
    
       #Incrémentation du compteur
       $i = $i + 1;
    }
 }

}

if ( $Compteur_Disable >= 1 ){
  #Modification de l'affichage et creation des donnees de performance pour le statut CRITICAL
  #Calcul du nombre d'Application désactivée
  $Compteur_Enable=$Compteur_Enable-$Compteur_Disable;
  $output = "Script (s) Disabled (s): $outputdisable";
  $perfdata ="Application_Enable=$Compteur_Enable";
  $status = 'CRITICAL';
} elsif  ( $Compteur_Enable == $i ){
  #Modification de l'affichage et creation des donnees de performance pour le statut WARNING
  $output = "All applications are enabled ($Compteur_Enable\\$i)";
  $perfdata ="Application_Enable=$Compteur_Enable";
}

#Affichage des informations dans Centreon
printf "$status %s|%s \n", $output, $perfdata;
exit $ERRORS{$status};
