use utf8;
package WGE::Model::Schema::Result::CrisprByGene;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::CrisprByGene::VERSION = '0.079';
}
## use critic


=head1 NAME

WGE::Model::Schema::Result::CrisprByGene

=head1 DESCRIPTION

Custom view that selects all crisprs given a list of exons

=cut

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

__PACKAGE__->table_class( 'DBIx::Class::ResultSource::View' );
__PACKAGE__->table( 'exon_crisprs' );

__PACKAGE__->result_source_instance->is_virtual(1);

#first bound value is an ensembl gene id, second is the species id
#take 22 off the chr_start so we can find crisprs that overlap start/end
__PACKAGE__->result_source_instance->view_definition( <<'EOT' );
WITH g as ( 
    SELECT ensembl_gene_id, chr_name, (chr_start-22) as chr_start, chr_end
    FROM genes
    WHERE genes.ensembl_gene_id=?
)
SELECT g.ensembl_gene_id, c.*
FROM g
JOIN crisprs c ON c.chr_name=g.chr_name AND c.chr_start>=g.chr_start AND c.chr_start<=g.chr_end
WHERE c.species_id=?
EOT

__PACKAGE__->add_columns(
    qw(
        ensembl_gene_id
        id
        chr_name
        chr_start
        seq 
        pam_right
        species_id
        off_target_ids
        off_target_summary
    )
);

__PACKAGE__->set_primary_key( "id" );

__PACKAGE__->belongs_to(
    "species",
    "WGE::Model::Schema::Result::Species",
    { id => "species_id" },
);


__PACKAGE__->meta->make_immutable;

1;
