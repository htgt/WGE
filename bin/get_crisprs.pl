#!/usr/bin/env perl

use strict;
use warnings;

use feature qw( say );

use YAML::Any qw( LoadFile );
use WGE::Util::FindCrisprs;
use Data::Dumper;

use WGE::Model::DB;

my $DB = WGE::Model::DB->new();

#
# TODO:
#   add some command line options to control species etc.
#   have a mode in this that is batch and one that is supplementary.
#   add model methods for creating a crispr to check it doesn't exist already.
#

for my $species ( map { $_->id } $DB->schema->resultset('Species')->all ) {
    #my $species = 'Mouse';
    say STDERR "Finding crisprs for $species";

    my $crispr_util = WGE::Util::FindCrisprs->new( species => $species, expand_seq => 0 );

    #get all the genes and exons
    my @genes = $DB->schema->resultset('Gene')->search( 
        { species_id => $species }, 
        { prefetch => 'exons' } 
    );

    unless ( @genes ) {
        say STDERR "No genes exist for $species, skipping.";
        next;
    }

    for my $gene ( @genes ) {
        #find crisprs for every exon associated with this gene
        my $crispr_data = $crispr_util->find_crispr_pairs( map { $_->ensembl_exon_id } $gene->exons );

        #get crispr data in a database friendly format
        my $all_crisprs = $crispr_util->get_crisprs( $crispr_data );
        while ( my ( $exon_id, $crisprs ) = each %{ $all_crisprs } ) {
            #we don't care about the crispr id so we just get the values
            for my $crispr ( values %{$crisprs} ) {
                my $relative_id = delete $crispr->{id}; #throw away relative ID

                $crispr->{species_id} = $species; #dont forget the old species

                #temporary until we have an index
                my @existing = $DB->schema->resultset('Crispr')->search( $crispr );
                my $db_crispr;
                if ( @existing ) {
                    $db_crispr = shift @existing; # take just the first one
                }
                else {
                    $db_crispr = $DB->schema->resultset('Crispr')->create( $crispr );
                }

                $crispr->{db_id} = $db_crispr->id;
            }
        }

        #get a hashref of pairs linking to the above crisprs and insert them
        my $pairs = $crispr_util->get_pairs( $crispr_data );
        $DB->schema->resultset('CrisprPair')->populate( $pairs );
    }

}

1;

__END__

=head1 NAME

get_crisprs.pl - find crisprs and pairs for every exon in the database for every species.

=head1 SYNOPSIS

get_crisprs.pl

Example usage:

perl ./bin/get_crisprs.pl

=head1 DESCRIPTION

Finds every exon for every species in the database, gets the sequence from ensembl and 
inserts the crisprs/pairs into the database.

Set which database to connect to using WGE_DB environment var.

=head AUTHOR

Alex Hodgkins

=cut