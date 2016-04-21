package WGE::Util::ExportCSV;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::ExportCSV::VERSION = '0.084';
}
## use critic

use strict;
use Data::Dumper;
use TryCatch;
use warnings FATAL => 'all';

=head1 NAME

WGE::Model::Util::GenomeBrowser

=head1 DESCRIPTION

Copied and adapted from LIMS2

=cut

use Sub::Exporter -setup => {
    exports => [ qw(
        write_design_data_csv
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

1;

