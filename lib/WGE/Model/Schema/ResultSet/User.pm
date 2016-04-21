use utf8;
package WGE::Model::Schema::ResultSet::User;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::ResultSet::User::VERSION = '0.086';
}
## use critic


use base 'DBIx::Class::ResultSet';

sub auto_create {
    my ( $self, $col_data ) = @_;

    my $new = $self->create($col_data);

    return $new;
}

1;
