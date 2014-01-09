use utf8;
package WGE::Model::Schema::ResultSet::Gene;

use base 'DBIx::Class::ResultSet';
use Try::Tiny;
use feature qw( say );

sub load_from_hash {
    my ( $self, $genes_yaml ) = @_;
    
    my $schema = $self->result_source->schema;

    while ( my ( $species, $genes ) = each %{ $genes_yaml } ) {
        my $species = ucfirst(lc $species);

        while ( my ( $gene_id, $gene ) = each %{ $genes } ) {
            my $exons = delete $gene->{ exons };

            #create gene entry
            try {
                my $db_gene = $self->update_or_create( 
                    {
                        ensembl_gene_id => $gene_id,
                        species_id      => $species,
                        %{ $gene },
                    },
                    { key => 'genes_ensembl_gene_id_key' } 
                );

                #insert exons
                while ( my ( $exon_id, $exon ) = each %{ $exons } ) {
                    $schema->resultset('Exon')->update_or_create( 
                        {
                            gene_id         => $db_gene->id,
                            ensembl_exon_id => $exon_id,
                            %{ $exon },
                        },
                        { key => 'exons_ensembl_exon_id_key' }  
                    );
                }
            }
            catch {
                say "Error inserting $gene_id: $_";
            };
        }
    }

    return;

}

1;
