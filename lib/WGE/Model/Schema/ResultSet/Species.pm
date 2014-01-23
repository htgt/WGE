use utf8;
package WGE::Model::Schema::ResultSet::Species;

use base 'DBIx::Class::ResultSet';
use Try::Tiny;

sub get_numerical_id {
    my ( $self, $species ) = @_;

    return $self->find(
        { id => $species }
    )->numerical_id;
}

1;
