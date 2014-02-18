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

Log::Log4perl->easy_init( $DEBUG );

#
# TODO:
#   the first thing this script will do is just update the status of a crispr pair,
#   so we can easily call it between steps
#
#   it must then call the calculate_off_targets method after establishing which pairs
#   are valid. we can do this with FindPairs i think? will have to pull all the crisprs
#   down first. ugh
#

my ( $left_id, $right_id, $species, @pair_ids );
my $status = "";
my $update_offs = 0;
GetOptions(
    "help"               => sub { pod2usage( 1 ) },
    "man"                => sub { pod2usage( 2 ) },
    "pair-ids=s{,}"      => \@pair_ids,
    "status=i"           => \$status,
    "update-offs!"       => \$update_offs,
    #for later
    "species=s"          => sub { my ( $name, $val ) = @_; $species = ucfirst( lc $val ); },
) or pod2usage( 2 );

die pod2usage( 2 ) unless @pair_ids;

my $client = LIMS2::REST::Client->new_with_config(
    configfile => $ENV{WGE_REST_CLIENT_CONFIG}
);

die "Nothing was changed - Please specify a status or --update-offs"
    unless $status or $update_offs;

for my $pair_id ( @pair_ids ) {
    my ( $left_id, $right_id ) = split "_", $pair_id;

    DEBUG "Processing pair $left_id, $right_id with status $status";

    #TODO: this should use species or it will get very slow.
    #that will mean updating the CrisprPair rest api
    #we could do it easily by making a new key that is (left_id,right_id,species_id)

    if ( $status ) {
        my $pair = update_status( $left_id, $right_id, $status );
    }

    if ( $update_offs ) {
       #additional rest call to launch the update
       DEBUG "Updating paired off targets";

       my $pair = update_offs( $left_id, $right_id );

       DEBUG "Paired off targets successfully updated.";
    }
}

#TODO: add bulk method that looks up based on pair_ids
sub update_status {
    my ( $left_id, $right_id, $status ) = @_;

    die "update_offs needs a left_id, right_id and a status" 
        unless $left_id and $right_id and $status;

    return $client->POST(
        'crispr_pair',
        { 
            left_id   => $left_id,
            right_id  => $right_id,
            status_id => $status,
        }
    );
}

sub update_offs {
    my ( $left_id, $right_id ) = @_;

    die "update_offs needs a left_id and right_id" 
        unless $left_id and $right_id;

    return $client->GET(
        'calculate_pair_off_targets',
        {
            left_id  => $left_id,
            right_id => $right_id
        }
    );
}


1;

__END__

=head1 NAME

update_crispr_pair.pl - update the status or off targets for a crispr pair 

=head1 SYNOPSIS

update_crispr_pair.pl [options]

    --species            mouse or human
    --pair-ids           pair ids in the format LeftCrispr_RightCrispr, e.g. 75275_75277
    --status             the status id to update the pair to
    --update-offs        update paired off targets, default is false [optional]
    --help               show this dialog

Example usage:

update_crispr_pair.pl --species Human --pair-ids 245377753_245377761 --status 3
update_crispr_pair.pl --species human --pair-ids 245377753_245377761 --update-offs

=head1 DESCRIPTION

Given a status id this will update the given pair, and given --update-offs 
will cause the off_target_ids and off_target_summary to be updated.

Calls REST methods within WGE

=head AUTHOR

Alex Hodgkins

=cut