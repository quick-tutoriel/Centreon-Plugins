#!/usr/bin/perl -w

##
## Plugin init
##
use strict;
use Getopt::Long;
use vars qw($opt_h $opt_community $opt_version $opt_host $opt_w $opt_c);
use lib "/usr/local/nagios3/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Net::SNMP;

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
##
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
my $snmp_oid= "SNMPv2-SMI::mib-2.47.1.1.1.1.7";

##
## Permet de faire un snmpwalk sur une feuille (OID)
##
my $resultOID = $session->get_table( -baseoid => $snmp_oid);
if (!defined($resultOID)) {
   printf ("UNKNOWN: %s. \n", $session->error);
   $session->close;
   exit ($ERRORS{'UNKNOWN'});
} 

my $perfdata = "";
my $status = 'OK';
my $output = "";

##
## Récupération des valeurs de OID et construction de notre affichage
## dans la variable $output. La variable $perfdata sert à sotcker les données de performance
##
foreach my $key ( sort(keys %$resultOID)) {

	if ( $key =~  /^.*\.(\d+)\.\d+$/ ) {
		my $index = $1;
        $perfdata = $perfdata . " CPU_switch_$index=" . $$resultOID{$key}.'%';
		$output = $output . "  CPU of switch $index: " . $$resultOID{$key}.'%';
		##
        ## Test des conditions pour attribuer le status CRITICAL ou WARNING
        ##
		if ( $$resultOID{$key} >= $opt_c ) {
			$status = 'CRITICAL';
		}
		elsif ( ($$resultOID{$key} >= $opt_w) and ($status ne 'CRITICAL') )
		{
                        $status = 'WARNING';
        }
	}
}

##
## Affichage des informations dans Centreon
## 
printf "$status %s | %s \n", $output, $perfdata;
exit $ERRORS{$status};
