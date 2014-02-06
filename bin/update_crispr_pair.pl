#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use LIMS2::REST::Client;
use YAML::Any qw( LoadFile DumpFile );
use Try::Tiny;
use Log::Log4perl qw( :easy );
use Data::Dumper;
use Path::Class;
use Bio::Perl qw( revcom );

Log::Log4perl->easy_init($DEBUG);

#
# TODO:
#   the first thing this script will do is just update the status of a crispr pair,
#   so we can easily call it between steps
#
#   it must then call the calculate_off_targets method after establishing which pairs
#   are valid. we can do this with FindPairs i think? will have to pull all the crisprs
#   down first. ugh
#

my ( $left_id, $right_id, $status, $species );
my $update_offs = 0;
GetOptions(
    "help"               => sub { pod2usage( 1 ) },
    "man"                => sub { pod2usage( 2 ) },
    "left_id=s"          => \$left_id,
    "right_id=s"         => \$right_id,
    "status=i"           => \$status,
    "update-offs!"       => \$update_offs,
    #for later
    "species=s"          => sub { my ( $name, $val ) = @_; $species = ucfirst( lc $val ); },
) or pod2usage( 2 );

die pod2usage( 2 ) unless $left_id and $right_id and $status;

my $client = LIMS2::REST::Client->new_with_config(
    configfile => $ENV{WGE_REST_CLIENT_CONFIG}
);

INFO "Updating pair $left_id,$right_id with status $status";

#TODO: this should use species or it will get very slow.
#that will mean updating the CrisprPair rest api
#we could do it easily by making a new key that is (left_id,right_id,species_id)
my $pair = $client->POST(
    'crispr_pair',
    { 
        left_id  => $left_id,
        right_id => $right_id,
        status   => $status,
    }
);

#if ( $update_offs ) {
#   #additional rest call to launch the update
#}


1;

__END__