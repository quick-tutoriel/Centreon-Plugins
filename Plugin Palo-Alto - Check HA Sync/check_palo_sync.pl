#!/usr/bin/perl

use strict;
use warnings;
use LWP::UserAgent;
use XML::Simple;
use Getopt::Long;

# Variables
my ($host, $apikey);
GetOptions(
    'host=s'   => \$host,
    'apikey=s' => \$apikey,
);

# Vérification des paramètres
if (!$host || !$apikey) {
    print "UNKNOWN - Paramètres manquants. Utilisation : --host <ip> --apikey <clé>\n";
    exit 3;
}

# URL d'interrogation HA
my $url = "https://$host/api/?type=op&cmd=<show><high-availability><state></state></high-availability></show>&key=$apikey";

# Crée l'agent avec options SSL désactivées
my $ua = LWP::UserAgent->new(
    ssl_opts => {
        verify_hostname => 0,
        SSL_verify_mode => 0x00,
    },
    timeout => 10,
);

# Requête HTTP GET
my $response = $ua->get($url);

# Gestion des erreurs de requête
if (!$response->is_success) {
    print "CRITICAL - Erreur HTTP : " . $response->status_line . "\n";
    exit 2;
}

# Parse XML
my $xml = XMLin($response->decoded_content, ForceArray => 0);

# Navigation dans les champs XML
my $running_sync         = $xml->{result}->{group}->{running_sync}         // '';
my $running_sync_enabled = $xml->{result}->{group}->{running_sync_enabled} // '';

# Comparaison insensible à la casse
if (lc($running_sync) eq 'synchronized' && lc($running_sync_enabled) eq 'yes') {
    print "OK - Configuration HA synchronisée\n";
    exit 0;
}
elsif (lc($running_sync_enabled) eq 'no') {
    print "WARNING - Synchronisation HA désactivée\n";
    exit 1;
}
else {
    print "CRITICAL - Synchronisation HA NON synchronisée : running_sync='$running_sync'\n";
    exit 2;
}
