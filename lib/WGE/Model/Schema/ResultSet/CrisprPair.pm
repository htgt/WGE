use utf8;
package WGE::Model::Schema::ResultSet::CrisprPair;

use base 'DBIx::Class::ResultSet';
use Try::Tiny;
use feature qw( say );

sub load_from_hash {
    my ( $self, $pairs_yaml, $test ) = @_;
    
    my $schema = $self->result_source->schema;

    while( my ( $id, $pair ) = each %{ $pairs_yaml } ) {
        try {
            #we have ids for this data already
            if ( $test ) {
                $pair{id} = $id;
            }

            $self->create( $pair );
        }
        catch {
            say "Error inserting: $id: $_";
        };
    }

    return;

}

1;
