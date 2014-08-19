#!/usr/bin/env perl

use strict;
use warnings;
use feature qw( say );

use Log::Log4perl ':easy';
use WGE::Model::DB;
use WGE::Util::FindPairs;
use Try::Tiny;
use List::MoreUtils qw( uniq );

BEGIN { Log::Log4perl->easy_init( { level => $DEBUG } ); }

die "Please provide at least two CRISPR IDs to check" unless @ARGV >= 2;

my $w = WGE::Model::DB->new;

{
    my @crisprs;
    for my $crispr_id ( @ARGV ) {
        DEBUG "Fetching crispr $crispr_id";
        my $crispr = $w->resultset('Crispr')->find( $crispr_id );
        die "Couldn't find $crispr_id" unless $crispr;
        push @crisprs, $crispr;
    }

    die "CRISPRs for different species" if ( uniq map { $_->species_id } @crisprs ) > 1;
    my $species_id = $crisprs[0]->species_id;

    #for now this will die if some are missing data
    data_missing( @crisprs );

    my @off_targets = get_all_off_targets( $species_id, map { $_->id } @crisprs );

    DEBUG "Checking a total of " . scalar( @off_targets ) . " off targets";

    my $pair_finder = WGE::Util::FindPairs->new(
        max_spacer  => 5000,
        include_h2h => 1
    );

    my $pairs =  $pair_finder->find_pairs( \@crisprs, \@crisprs );

    DEBUG "Found " . scalar( @$pairs ) . " off targets:";

    if ( @$pairs ) {
        say join "\t", qw( left_id left_region spacer right_id right_region );
    }
    else {
        DEBUG "No potential off targets found";
    }

    for my $pair ( sort { $a->{spacer} <=> $b->{spacer} } @{ $pairs } ) {
        say join "\t", $pair->{left_crispr}{id}, 
                       region_str( $pair->{left_crispr} ),
                       $pair->{spacer}, 
                       $pair->{right_crispr}{id},
                       region_str( $pair->{right_crispr} );
    }
}

sub region_str {
    my ( $crispr ) = @_;

    return $crispr->{chr_name} . ":" . $crispr->{chr_start} . "-" . $crispr->{chr_end};
}

#TODO: make this update any crisprs with missing off targets
sub data_missing {
    my ( @crisprs ) = @_;

    my @missing = grep { ! $_->off_target_summary } @crisprs;
    return 0 unless @missing;

    die "The following IDs are missing data: " . join ", ", map { $_->id } @missing; 
}

sub get_all_off_targets {
    my ( $species_id, @ids ) = @_;

    return $w->resultset('CrisprOffTargets')->search(
      {},
      {
        bind => [
          '{' . join( ",", @ids ) . '}',
          $species_id,
          $species_id
        ]
      }
    );
}


1;

__END__

=head1 NAME

label_crisprs.pl - set all crisprs as exonic/genic for an exon/gene

=head1 SYNOPSIS

label_crisprs.pl [options]

    --species            mouse or human
    --exon-id-file       file containing exon ids 1 per line (not ensembl exon ids)
    --gene-id-file       gene containing gene ids 1 per line
    --reset              set the field to 0 instead of 1
    --commit             persist the data (default is false)
    --help               show this dialog

Example usage:

label_crisprs.pl --species human --exon-id-file human_exons.txt --commit
label_crisprs.pl --species mouse --gene-id-file mouse_ids.txt --reset --commit

=head1 DESCRIPTION

Given a file containing exon db ids or gene db ids (NOT ensembl exon ids) update
the crisprs within the region
to be exonic/genic

Note: exonic/genic are labelled independently, so exons must be run once under genes
and once under exons to have both flags set.

This logic is duplicated in Crisprs/wge_update_crispr.pl

=head AUTHOR

Alex Hodgkins

=cut
