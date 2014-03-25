#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use WGE::Model::DB;
use Log::Log4perl qw( :easy );
use Const::Fast;
use IO::File;
use Text::CSV;
use Bio::Perl qw( revcom );
use feature qw( say );
use Smart::Comments;

const my $REGION_LENGTH => 1000;
const my $NUM_CRISPRS   => 5;
#TODO work this out dynamically using the above variables
const my @SPREAD        => qw( 100 300 500 700 900 );

Log::Log4perl->easy_init($DEBUG);

GetOptions(
    "species=s" => \my $species,
    "gene=s"    => \my $gene,
);

my $DB = WGE::Model::DB->new();

die 'Need Species' unless $species;

my @output_column_names
    = qw( crispr_seq crispr_guide_seq crispr_order_seq start end chromosome crispr_id pam_right gene );
my $output_fh = IO::File->new( 'crispr_order_sequence.csv', 'w' );
my $crispr_order_csv = Text::CSV->new( { eol => "\n" } );
$crispr_order_csv->print( $output_fh, \@output_column_names );

my %search_params;
$search_params{species_id} = $species;
$search_params{marker_symbol} = $gene if $gene;
my $genes_rs = $DB->schema->resultset("Gene")->search_rs( \%search_params, { prefetch => 'exons' } );
my $species_id = $species eq 'Mouse' ? 2 : 1;

while ( my $gene = $genes_rs->next ) {    ### Working===[%]     done
    # exons are ranked so the 5' most exon is always rank 1
    my $five_prime_exon = $gene->exons->find( { rank => 1 } );

    next if $gene->chr_name eq 'MT';

    # work out coordinates for region 1000 bases 5' of the exon
    my ( $start, $end );
    if ( $gene->strand == 1 ) {
        $start = $five_prime_exon->chr_start - $REGION_LENGTH;
        $end   = $five_prime_exon->chr_start - 1;
    }
    else {
        $start = $five_prime_exon->chr_end + 1;
        $end   = $five_prime_exon->chr_end + $REGION_LENGTH;
    }

    # find all crisprs in region that are in the same orientation as the gene
    my $pam_right = $gene->strand == 1 ? 1 : 0;
    my @crisprs = $DB->schema->resultset("Crispr")->search(
        {   species_id => $species_id,
            chr_name   => $gene->chr_name,
            chr_start  => { -between => [ $start, $end ] },
            pam_right  => $pam_right,
        }
    );

    my $output_crisprs;
    if ( scalar(@crisprs) < 6 ) {
        $output_crisprs = \@crisprs;
    }
    else {
        $output_crisprs = spaced_crisprs( \@crisprs, $start );
    }
    print_crispr_bed( $gene, $output_crisprs, $start );
    print_crispr_order_csv( $output_crisprs, $gene );
}

=head print_crispr_bed

Print the crisprs out in a bed file format
BED format: chromosome, start, end, name, score, strand

=cut
sub print_crispr_bed {
    my ( $gene, $crisprs, $start ) = @_;

    my $chr = $gene->chr_name;
    for my $crispr ( @{$crisprs} ) {
        my $name
            = $gene->marker_symbol . ':' . $crispr->id . ':' . abs( $start - $crispr->chr_start );

        # NOTE: bed files are 0-base, our coordinates are one based, so take one from the chr_start
        #       we do not take one from the end because the end coordinate is not inclusive for bed files
        say join "\t",
            ( 'chr' . $chr, $crispr->chr_start - 1, $crispr->chr_end, $name,, $gene->strand );
    }
}

=head print_crispr_order_sheet

Print a order sheet for the crisprs, this in in the format Manos wanted.
The append / prepend sequences are hard coded here, should change this.

=cut
sub print_crispr_order_csv {
    my ( $crisprs, $gene ) = @_;
    my %crispr_data;

    for my $crispr ( @{$crisprs} ) {
        $crispr_data{crispr_seq} = $crispr->seq;
        my $guide_seq = guide_rna($crispr);
        $crispr_data{crispr_guide_seq} = $guide_seq;
        $crispr_data{crispr_order_seq}
            = 'GCAGATGGCTCTTTGTCCTAGACATCGAAGACAACACCG' . $guide_seq . 'GTTTTACAGTCTTCTCGTCGC';
        $crispr_data{start}      = $crispr->chr_start;
        $crispr_data{end}        = $crispr->chr_end;
        $crispr_data{chromosome} = $crispr->chr_name;
        $crispr_data{crispr_id}  = $crispr->id;
        $crispr_data{pam_right}  = $crispr->pam_right;
        $crispr_data{gene}       = $gene->marker_symbol;

        $crispr_order_csv->print( $output_fh, [ @crispr_data{@output_column_names} ] );
    }

}

=head guide_rna

Strip the PAM site and the must 5' base from the stored crispr sequence.
Also revcomp the sequence if needed ( we store all out sequence on the global +ve strand )

=cut
sub guide_rna {
    my ($crispr) = @_;

    if ( !defined $crispr->pam_right ) {
        return substr( $crispr->seq, 1, 19 );
    }
    elsif ( $crispr->pam_right == 1 ) {
        return substr( $crispr->seq, 1, 19 );
    }
    elsif ( $crispr->pam_right == 0 ) {

        #its pam left, so strip first three characters and the very last one,
        #we revcom so that the grna is always relative to the NGG sequence
        return revcom( substr( $crispr->seq, 3, 19 ) )->seq;
    }
    else {
        die "Unexpected value in pam_right: " . $crispr->pam_right;
    }

}

=head spaced_crisprs

Pick 5 crisprs in the target region that are spaced out evenly

=cut
sub spaced_crisprs {
    my ( $crisprs, $start ) = @_;
    my @spaced_crisprs;
    my %seen_crisprs;

    for my $gap (@SPREAD) {
        my $ideal_point = $start + $gap;

        # rank crisprs by closeness to the ideal point on genome
        # also filter out any already picked crisprs
        my $crispr
            = ( sort { abs( $ideal_point - $a->chr_start ) <=> abs( $ideal_point - $b->chr_start ) }
                grep { !exists $seen_crisprs{ $_->id } } @{$crisprs} )[0];

        $seen_crisprs{ $crispr->id } = 1;
        push @spaced_crisprs, $crispr;
    }

    return \@spaced_crisprs;
}

=head1 NAME

promotor_region_crisprs.pl - find groups of crisprs in gene promotor region

=head1 SYNOPSIS

promotor_region_crisprs.pl [options]

    --species         Mouse or Human
    --gene            Gene marker symbol ( optional )

Example usage:

find_crisprs.pl --species Human

To run script for just one gene use --gene option to specify a gene marker symbol

=head1 DESCRIPTION

Manos asked us to find crisprs with the following criteria:

Will take all the genes for Mouse of Human in WGE ( only protein coding genes stored currently ).
Then locates all our crisprs in 1000 base region before the start of the 5' most exon ( on canonical transcript )
If more than 5 crisprs found we return a set of 5 crisprs that are spaced out as evenly as possible in the 1000 base pair region.

Output is a bed file and a crispr order sheet.
Currently the crispr order sheet has hard coded custom sequence tagged onto the 5' and 3' ends.

=cut
