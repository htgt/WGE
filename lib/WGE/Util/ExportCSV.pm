package WGE::Util::ExportCSV;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::ExportCSV::VERSION = '0.087';
}
## use critic

use strict;
use Data::Dumper;
use TryCatch;
use warnings FATAL => 'all';

use Scalar::Util qw(blessed);

=head1 NAME

WGE::Model::Util::GenomeBrowser

=head1 DESCRIPTION

Copied and adapted from LIMS2

=cut

use Sub::Exporter -setup => {
    exports => [ qw(
        write_design_data_csv
        format_crisprs_for_csv
        format_pairs_for_csv
    ) ]
};

use Log::Log4perl qw( :easy );

sub write_design_data_csv{
    my ($design_data, $display_list) = @_;

    # display_list is and array of arrays containing
    # a field title, followed by field accessor e.g.
    #( ["Design id","id"] )
    # Same as used by view_design.tt

    my @content;
    foreach my $item ( @{ $display_list || [] } ){
        push @content, (join ',', $item->[0], $design_data->{ $item->[1] } );
    }

    push @content, "";
    push @content, 'Oligos: ';
    push @content, (join ',','Type','Chromosome','Start','End','Sequence on +ve strand', 'Sequence as Ordered');

    foreach my $oligo (@{ $design_data->{oligos} || [] }){
        push @content, (join ',',
        	$oligo->{type},
        	$oligo->{locus}->{chr_name},
        	$oligo->{locus}->{chr_start},
        	$oligo->{locus}->{chr_end},
        	$oligo->{seq},
            $design_data->{oligo_order_seqs}{ $oligo->{type} },
        );
    }

    my $string = join "\n", @content;

    return $string;
}

sub format_crisprs_for_csv{
    my ($crispr_list, $with_exon_id) = @_;

    $crispr_list ||= [];

    # Make sure we have hashes instead of objects
    my @crisprs = map { blessed($_) ? $_->as_hash : $_ } @$crispr_list;

    my @csv_data;
    my @fields = qw( crispr_id location strand seq off_target_summary );
    if($with_exon_id){
        unshift @fields, 'exon_id';
    }
    push @csv_data, \@fields;

    foreach my $crispr ( @crisprs ) {
        my $location = $crispr->{chr_name}.":".$crispr->{chr_start}."-".$crispr->{chr_end};
        my $strand = $crispr->{pam_right} ? "+" : "-";
        my @row = (
            $crispr->{id},
            $location,
            $strand,
            $crispr->{seq},
            $crispr->{off_target_summary} // '',
        );
        if($with_exon_id){
            unshift @row, ($crispr->{ensembl_exon_id} // '');
        }
        push @csv_data, \@row;
    }

    return \@csv_data;
}

sub format_pairs_for_csv{
    my ($pair_list, $with_exon_id) = @_;

    $pair_list ||= [];
    # Make sure we have hashes instead of objects
    my @pairs = map { blessed($_) ? $_->as_hash : $_ } @$pair_list;

    my @csv_data;
    my @fields = qw( pair_id spacer pair_status summary );
    my @crispr_fields = qw( id location seq off_target_summary );
    if($with_exon_id){
        unshift @fields, 'exon_id';
    }

    for my $orientation ( qw( l r ) ) {
        push @fields, map { $orientation . "_" . $_ } @crispr_fields;
    }

    push @csv_data, \@fields;

    for my $pair ( @pairs ) {
        my ( $status, $summary ) = ("Not started", "");

        if ( $pair->{db_data} ) {
            $status  = $pair->{db_data}{status} if $pair->{db_data}{status};
            $summary = $pair->{db_data}{off_target_summary} if $pair->{db_data}{off_target_summary};
        }

        my @row = (
            $pair->{id},
            $pair->{spacer},
            $status,
            $summary,
        );

        if($with_exon_id){
            unshift @row, $pair->{ensembl_exon_id};
        }

        #add all the individual crispr fields for both crisprs
        for my $dir ( qw( left_crispr right_crispr ) ) {
            #mirror ensembl location format
            $pair->{$dir}{location} = $pair->{$dir}{chr_name}  . ":"
                              . $pair->{$dir}{chr_start} . "-"
                              . $pair->{$dir}{chr_end};

            push @row, map { $pair->{$dir}{$_} || "" } @crispr_fields;
        }

        push @csv_data, \@row;
    }
    return \@csv_data;
}
1;

