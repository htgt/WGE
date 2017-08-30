package WGE::Util::ExportCSV;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::ExportCSV::VERSION = '0.107';
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
        format_crisprs_for_bed
        format_pairs_for_bed
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

sub format_crisprs_for_csv {
    my ($crispr_list, $with_exon_id) = @_;

    $crispr_list ||= [];

    # Make sure we have hashes instead of objects
    my @crisprs = map { blessed($_) ? $_->as_hash : $_ } @$crispr_list;

    my @csv_data;
    my @fields = qw( crispr_id location strand seq gRNA off_target_summary );
    if($with_exon_id){
        unshift @fields, 'exon_id';
    }
    push @csv_data, \@fields;

    foreach my $crispr ( @crisprs ) {
        my $location = $crispr->{chr_name}.":".$crispr->{chr_start}."-".$crispr->{chr_end};
        my $strand = $crispr->{pam_right} ? "+" : "-";
        my $gRNA;
        if ($crispr->{pam_right}) {
            $gRNA = $crispr->{seq};
        }
        else {
            $gRNA = reverse $crispr->{seq};             #reverse direction of crispr. E.G. CCN N...N becomes N...N NCC
            $gRNA =~ tr/ATCG/TAGC/;                     #complement crispr sequence.  E.G. C...A ACC becomes G...T TGG
        }
        my @row = (
            $crispr->{id},
            $location,
            $strand,
            $crispr->{seq},
            $gRNA,
            $crispr->{off_target_summary} // '',
        );
        if($with_exon_id){
            unshift @row, ($crispr->{ensembl_exon_id} // '');
        }
        push @csv_data, \@row;
    }

    return \@csv_data;
}

sub format_pairs_for_csv {
    my ($pair_list, $with_exon_id) = @_;

    $pair_list ||= [];
    # Make sure we have hashes instead of objects
    my @pairs = map { blessed($_) ? $_->as_hash : $_ } @$pair_list;

    my @csv_data;
    my @fields = qw( pair_id spacer pair_status summary );
    my @crispr_fields = qw( id location seq gRNA off_target_summary );
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

        $pair->{left_crispr}{gRNA} = reverse $pair->{left_crispr}{seq};
        $pair->{right_crispr}{gRNA} = $pair->{right_crispr}{seq};
        $pair->{left_crispr}{gRNA} =~ tr/ATCG/TAGC/;

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

sub format_crisprs_for_bed {
    my ($crispr_list, $with_exon_id) = @_;

    $crispr_list ||= [];

    # Make sure we have hashes instead of objects
    my @crisprs = map { blessed($_) ? $_->as_hash : $_ } @$crispr_list;

    my @bed_data;
    my @fields = qw( chrom chrom_start chrom_end name seq gRNA strand );
    if($with_exon_id){
        unshift @fields, 'exon_id';
    }
    push @bed_data, \@fields;

    foreach my $crispr ( @crisprs ) {
        my $chrom = "chr".$crispr->{chr_name};
        my $strand = $crispr->{pam_right} ? "+" : "-";
        my $gRNA;
        if ($crispr->{pam_right}) {
            $gRNA = $crispr->{seq};
        }
        else {
            $gRNA = reverse $crispr->{seq};         #reverse direction of crispr. E.G. CCN N...N becomes N...N NCC
            $gRNA =~ tr/ATCG/TAGC/;                 #complement crispr sequence.  E.G. C...A ACC becomes G...T TGG
        }
        my @row = (
            $chrom,
            $crispr->{chr_start},
            $crispr->{chr_end},
            $crispr->{id},
            $crispr->{seq},
            $gRNA,
            $strand // '',
        );
        if($with_exon_id){
            unshift @row, ($crispr->{ensembl_exon_id} // '');
        }
        push @bed_data, \@row;
    }

    return \@bed_data;
}

sub format_pairs_for_bed {
    my ($pair_list, $with_exon_id) = @_;

    $pair_list ||= [];
    # Make sure we have hashes instead of objects
    my @pairs = map { blessed($_) ? $_->as_hash : $_ } @$pair_list;

    my @bed_data;
    my @fields = qw( pair_id spacer pair_status summary );
    my @crispr_fields = qw( chrom chrom_start chrom_end name seq gRNA strand );
    if($with_exon_id){
        unshift @fields, 'exon_id';
    }

    for my $orientation ( qw( l r ) ) {
        push @fields, map { $orientation . "_" . $_ } @crispr_fields;
    }

    push @bed_data, \@fields;

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

        $pair->{left_crispr}{gRNA} = reverse $pair->{left_crispr}{seq};
        $pair->{right_crispr}{gRNA} = $pair->{right_crispr}{seq};
        $pair->{left_crispr}{gRNA} =~ tr/ATCG/TAGC/;

        #add all the individual crispr fields for both crisprs
        for my $dir ( qw( left_crispr right_crispr ) ) {
            #mirror ensembl location format
            $pair->{$dir}{chrom} = "chr" . $pair->{$dir}{chr_name};
            $pair->{$dir}{chrom_start} = $pair->{$dir}{chr_start};
            $pair->{$dir}{chrom_end} = $pair->{$dir}{chr_end};

            push @row, map { $pair->{$dir}{$_} || "" } @crispr_fields;
        }

        push @bed_data, \@row;
    }

    return \@bed_data;
}

1;