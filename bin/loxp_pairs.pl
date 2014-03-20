#!/usr/bin/env perl
use strict;
use warnings;

use WGE::Model::DB;
use Data::Dumper;
use Text::CSV;
use IO::Handle;

use feature qw( say );

die "Usage: loxp_pairs.pl <loci.csv>" unless @ARGV;

my $w = WGE::Model::DB->new;

my $csv = Text::CSV->new();
open ( my $fh, '<', $ARGV[0] ) or die( "Can not open $ARGV[0] " . $! );
# gene, project, design_id, project_status, tv_plate, tv_well, design_id, design_type, chr_name, loxp_start, loxp_end, delsize, number_ccs, number_ggs, spacer, seq
$csv->column_names( @{ $csv->getline( $fh ) } );

my @output_column_names = $csv->column_names;
push @output_column_names, qw( crisprs pairs );

my $output = IO::Handle->new_from_fd( \*STDOUT, 'w' );
my $output_csv = Text::CSV->new( { eol => "\n" } );
$output_csv->print( $output, \@output_column_names  );

while ( my $data = $csv->getline_hr( $fh ) ) {

    my $crisprs = crisprs_for_region( $data->{chr_name}, $data->{loxp_start}, $data->{loxp_end} );
    my $pairs = crispr_pairs_for_region( $crisprs, $data->{loxp_start}, $data->{loxp_end} );

    $data->{crisprs} = scalar( @{ $crisprs } );
    $data->{pairs} = scalar( @{ $pairs } );

    $output_csv->print( $output, [ @{ $data }{ @output_column_names } ] );
}

sub crisprs_for_region {
    my ( $chr_name, $chr_start, $chr_end ) = @_;

    say STDERR "Getting crisprs for $chr_name:${chr_start}-${chr_end}";

    # we use 90 because the spaced between the crisprs in a pair can be 50 bases.
    # 50 + the size of 2 crisprs is around 90
    # that should bring back all the possible crisprs we want ( and some we do not want
    # which we must filter out )
    my @crisprs = $w->resultset('Crispr')->search(
        {
            'species_id'  => 2,
            'chr_name'    => $chr_name,
            # need all the crisprs starting with values >= start_coord
            # and whose start values are <= end_coord
            'chr_start'   => { 
                -between => [ $chr_start - 90, $chr_end + 90 ],
            },
        },
    )->all;

    return \@crisprs;
}

=head crispr_pairs_for_region

Identifies pairs within the list of crisprs for the region

=cut
sub crispr_pairs_for_region {
    my ( $crisprs, $loxp_start, $loxp_end ) = @_;

    # Find pairs amongst crisprs
    my $pair_finder = WGE::Util::FindPairs->new;
    my $pairs = $pair_finder->find_pairs( $crisprs, $crisprs );

    return validate_crispr_pairs( $pairs, $loxp_start, $loxp_end ); 
}

sub validate_crispr_pairs {
    my ( $pairs, $start, $end ) = @_;
    my @validated_pairs;

    for my $pair ( @{ $pairs } ) {
        if (   crispr_in_target_region( $pair->{left_crispr}, $start, $end )
            || crispr_in_target_region( $pair->{right_crispr}, $start, $end ) )
        {
            push @validated_pairs, $pair;
        }
    }

    return \@validated_pairs;
}

sub crispr_in_target_region {
    my ( $crispr, $start, $end ) = @_;

    if ( $crispr->{pam_right} ) {
        if ( $crispr->{chr_end} > $start && $crispr->{chr_end} <= $end ) {
            return 1;
        }
    }
    else {
        if ( $crispr->{chr_start} >= $start && $crispr->{chr_start} < $end ) {
            return 1;
        }
    }
    
    return;
}

1;
