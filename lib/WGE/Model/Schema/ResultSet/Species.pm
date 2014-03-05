use utf8;
package WGE::Model::Schema::ResultSet::Species;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::ResultSet::Species::VERSION = '0.005';
}
## use critic


use base 'DBIx::Class::ResultSet';
use Try::Tiny;

sub get_numerical_id {
    my ( $self, $species ) = @_;

    return $self->find(
        { id => $species }
    )->numerical_id;
}

1;
