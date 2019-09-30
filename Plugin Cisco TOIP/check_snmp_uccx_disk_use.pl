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
my $outputcritical;
my $outputwarning;
my $label_disk = "";
my $result_label_disk = "";
my $label_session = "";
my $size_disk = "";
my $size_session = "";
my $result_size_disk = "";
my $used_disk = "";
my $used_session = "";
my $result_used_disk = "";
my $pourcentage_disk_used = 0;
my $StorageType;
my $label_StorageType;
my $result_label_StorageType;
my $Critical_Error = 0;
my $Warning_Error = 0;


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

#OID permettant de recuperer le load de chaque core du processeur, dans la MIB HOST-RESOURCES-MIB
my $snmp_oid= ".1.3.6.1.2.1.25.2.3.1";

my $resultOID = $session->get_table( -baseoid => $snmp_oid);
if (!defined($resultOID)) {
   printf ("UNKNOWN: %s. \n", $session->error);
   $session->close;
   exit ($ERRORS{'UNKNOWN'});
} 

#Recuperation de l'utilisation du disque
foreach my $key ( sort(keys %$resultOID)) {

 #Récupération de l'index du tableau
 if ($key =~ /.1.3.6.1.2.1.25.2.3.1.1./){
               
    #Recuperation du hrStorageType.
    $StorageType = ".1.3.6.1.2.1.25.2.3.1.2." . "$$resultOID{$key}";
    $label_StorageType = $session->get_request(-varbindlist => [ $StorageType]);
    $result_label_StorageType = $label_StorageType->{$StorageType};
     
   #On vérifie si le StorageType est bien à hrStorageFixedDisk
   if ($result_label_StorageType eq ".1.3.6.1.2.1.25.2.1.4"){

            #Recuperation du Label du disque.
            $label_disk = ".1.3.6.1.2.1.25.2.3.1.3." . "$$resultOID{$key}";
            $label_session = $session->get_request(-varbindlist => [$label_disk]);
            $result_label_disk = $label_session->{$label_disk};
            #$result_label_disk = substr($result_label_disk,0,2); 
                       
            #Recuperation de la taille du disque ou de la partition.
            $size_disk = ".1.3.6.1.2.1.25.2.3.1.5." . "$$resultOID{$key}";
            $size_session = $session->get_request(-varbindlist => [$size_disk]);
            $result_size_disk = $size_session->{$size_disk};
            
            #Recuperation de l'espace utilise sur le disque ou la partition.
            $used_disk = ".1.3.6.1.2.1.25.2.3.1.6." . "$$resultOID{$key}";
            $used_session = $session->get_request(-varbindlist => [$used_disk]);
            $result_used_disk = $used_session->{$used_disk};

            #Calcul du pourcentage d'utilisation du disque ou de la partition.
            $pourcentage_disk_used = ($result_used_disk * 100) / $result_size_disk;
            $pourcentage_disk_used = sprintf("%.0f", $pourcentage_disk_used);
            
            #Construction de l'affichage pour Centreon.
            $output = $output . " $result_label_disk=$pourcentage_disk_used%"; 
            $perfdata = $perfdata. "$result_label_disk=$pourcentage_disk_used;$opt_w;$opt_c;0;100,";

            #Recuperation du statut du service et création d'une sortie. 
            if ( $pourcentage_disk_used >= $opt_c ) {
		    $Critical_Error = $Critical_Error + 1;
                    $outputcritical = $outputcritical . " $result_label_disk=$pourcentage_disk_used%"; 
		}
		elsif ( ($pourcentage_disk_used >= $opt_w) and ($status ne 'CRITICAL') ){
                    $Warning_Error = $Warning_Error + 1;
                    $outputwarning = $outputwarning . " $result_label_disk=$pourcentage_disk_used%";  
                }
  }
 }
         
}

if ( $Critical_Error >= 1 ){
  #Modification de l'affichage et creation des donnees de performance pour le statut CRITICAL
  $output = "Space Used per Disc " . $outputcritical . " (Seuils W:$opt_w C:$opt_c)";
  $status = 'CRITICAL';
} elsif  ( $Warning_Error >= 1 ){
  #Modification de l'affichage et creation des donnees de performance pour le statut WARNING
  $output = "Space Used per Disc " . $outputwarning . " (Seuils W:$opt_w C:$opt_c)";
  $status = 'WARNING';
} else {
  #Modification de l'affichage et creation des donnees de performance pour le statut OK
  $output = "Space Used per Disc " .$output . " (Seuils W:$opt_w C:$opt_c)";
}

#Affichage des informations dans Centreon
printf "$status %s|%s \n", $output, $perfdata;
exit $ERRORS{$status};

