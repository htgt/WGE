#!/usr/bin/env perl

use strict;
use warnings;

use feature qw( say );

use Getopt::Long;
use Pod::Usage;
use LIMS2::Util::EnsEMBL;
use YAML::Any qw( DumpFile );
use Data::Dumper;

my $biotype = 'protein_coding';
my @species = ( 'human', 'mouse' );
my $output_folder = ""; #default to cwd

GetOptions(
    'help'            => sub { pod2usage( 1 ) },
    'man'             => sub { pod2usage( 2 ) },
    'biotype=s'       => \$biotype,
    'species=s@'      => \@species,
    'output-folder=s' => \$output_folder,
) or pod2usage( 2 );

for my $species ( @species ) {
    say "Getting genes for $species";
    my $e = LIMS2::Util::EnsEMBL->new( species => $species );
    my $ens_version = $e->gene_adaptor->schema_version;

    #if they say all we should just do a fetch_all 
    my $genes = $e->gene_adaptor->fetch_all_by_biotype( $biotype );
    #my $genes = [ $e->gene_adaptor->fetch_by_stable_id( "ENSG00000108468" ) ];
    #my $genes = [ $e->gene_adaptor->fetch_by_stable_id( "ENSMUSG00000018666" ) ];

    my %genes_yaml;

    my %gene_fields = (
        marker_symbol   => 'external_name',
        strand          => 'seq_region_strand',
        chr_start       => 'seq_region_start',
        chr_end         => 'seq_region_end',
        chr_name        => 'seq_region_name',
    );

    my %exon_fields = (
        chr_start  => 'seq_region_start',
        chr_end    => 'seq_region_end',
        chr_name   => 'seq_region_name',
    );

    while ( my $gene = shift @{ $genes } ) {

        #add all the gene fields
        $genes_yaml{ $gene->stable_id } =
            get_fields( 
                $gene, 
                \%gene_fields, 
                canonical_transcript => $gene->canonical_transcript->stable_id 
            );

        #populate the exons hash
        my $rank = 1;
        for my $exon ( @{ $gene->canonical_transcript->get_all_Exons} ) {
            $genes_yaml{ $gene->stable_id }->{ exons }{ $exon->stable_id } =
                get_fields( 
                    $exon, 
                    \%exon_fields, 
                    rank => $rank++
                );
        }
    }

    DumpFile( "${species}_genes_${ens_version}.yaml", { $species => \%genes_yaml } );
}

#method to extract data from an ensembl object driven by a hash of keys mapped 
#to method names any additional parameters are added into the data hash.
sub get_fields {
    my ( $object, $fields, %data ) = @_;

    while ( my ( $field_name, $method ) = each %{ $fields } ) {
        $data{ $field_name } = $object->$method;
    }

    return \%data;
}

1;

__END__

=head1 NAME

get_all_genes.pl - given a species fetch all genes and exons, storing the output in a yaml file

=head1 SYNOPSIS

get_all_genes.pl [options]
               
    --species          The species to fetch the data for. Can be multiple.
    --biotype          The biotype to give to the ensembl gene adaptor fetch, defaults to protein coding.
    --output-folder    Change where the yaml file is output. Defaults to cwd
    --help             show this dialog

Example usage:

perl ./bin/get_all_genes.pl --species mouse

=head1 DESCRIPTION

Dumps all genes and exons for the given species to a yaml file, which can be loaded to the db with load_genes.pl

The yaml file name is <species>_genes_<ensembl_version>.yaml

=head AUTHOR

Alex Hodgkins

=cut