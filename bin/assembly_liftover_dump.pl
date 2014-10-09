#!/usr/bin/env perl
use strict;
use warnings;

use WGE::Model::DB;
use IO::File;
use feature qw( say );

my $model = WGE::Model::DB->new;
my $species = $ARGV[0];

my @loci = $model->schema->resultset('DesignOligoLoci')->search(
    {
        'design.species_id' => $species,
        assembly_id         => 'GRCh37',
    },
    {
        join     => { 'design_oligo' => 'design' },
        prefetch => 'chr',
    }
);

print_bed_file( \@loci ); 

sub print_bed_file {
    my ( $loci ) = @_;

    my $fh = IO::File->new( 'wge_design_oligos.bed' , 'w' );

    foreach my $locus ( @{ $loci } ) {
        say $fh join "\t",
            "chr" . $locus->chr->name,
            $locus->chr_start,
            $locus->chr_end,
            $locus->design_oligo_id . ":" . $locus->chr_strand;
    }

}
