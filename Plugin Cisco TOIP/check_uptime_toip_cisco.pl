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
 "H=s"	=>	\$opt_host,		"host=s"	=> \$opt_host,
 "w=s"	=>	\$opt_w,		"warning=s"	=> \$opt_w,
 "c=s"	=>	\$opt_c,		"critical=s"	=> \$opt_c);

if ($opt_h){
  print "Usage du plugin :\n";
  print "-h (--help) 		Affiche l'aide\n";
  print "-C (--community)	Valeur de la communaute\n";
  print "-V (--version)		SNMP Version (1-2C-3)\n";
  print "-H (--hostname)	Adresse IP de l'host\n";
  print "-w (--warning) 	Valeur Warning en centième d'heures\n";
  print "-c (--critical)	Valeur Critical en centième d'heures\n";
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
## -translate : Permet de convertir le résultat d'un OID
## -timeticks : Permet de récupérer la valeur de l'OID en centième d'heures et non format texte
my ($session, $error) = Net::SNMP ->session(-community => $opt_community,
					    -version => $opt_version,
					    -hostname => $opt_host,
					    -translate   => [
	                                    -timeticks => 0x0
					    ]
					    );
if (!defined($session)){
  print ("UNKNOWN: $error\n");
  exit ($ERRORS{'UNKNOWN'});
}

##
## Description de votre OID
## Permet de récupérer l'uptime d'un switch
my $snmp_oid_uptime = ".1.3.6.1.2.1.25.1.1.0";


##
## Permet de faire un get sur une feuille (OID)
##
my $resultOID = $session->get_request(-varbindlist => [$snmp_oid_uptime]);
if (!defined($resultOID)) {
	printf("UNKNOWN: %s.\n", $session->error);
	$session->close;
	exit $ERRORS{'UNKNOWN'};
}

##
## Récupération de la valeur de OID
##
my $result = $resultOID->{$snmp_oid_uptime};


##
## Déclaration d'une variable pour récupérer le statut, pour l'afficher dans la sortie. Par défaut OK
##
my $status = 'OK';
my $output = "";
my $perfdata = "";


## Conversion du résultat en JJ-HH-MM-SS
my $minute=int($result / 6000);
my $UPTDAY=int($minute / 60 / 24 );
my $UPTMINT=int(( $UPTDAY * 1440 ));
my $UPTMINM=int(( $minute - $UPTMINT ));
my $UPTMINH=int($UPTMINM / 60 );
my $UPTMINHM=int(( $UPTMINH * 60 ));
my $UPTMINHMS=int(( $UPTMINM - $UPTMINHM ));


##
## Test des conditions pour attribuer le status CRITICAL ou WARNING
##
if ( $result <= $opt_c ) {
       $status = 'CRITICAL';
       $output = $output . "Device Rebooted $UPTDAY Jours $UPTMINH Heures $UPTMINHMS Minutes";
       $perfdata = $perfdata . "UP=$UPTDAY";
      }
	elsif ($result <= $opt_w && $result > $opt_c){
           $status = 'WARNING';
           $output = $output . "Device Rebooted $UPTDAY Jours $UPTMINH Heures $UPTMINHMS Minutes";
           $perfdata = $perfdata . "UP=$UPTDAY";
      }
	else {
  	   $status = 'OK';
           $output = $output . "Device UP $UPTDAY Jours $UPTMINH Heures $UPTMINHMS Minutes";
           $perfdata = $perfdata . "UP=$UPTDAY";
      }

##
## Affichage du résultat dans Centreon
printf "$status %s | %s \n", $output, $perfdata;
exit $ERRORS{$status};



