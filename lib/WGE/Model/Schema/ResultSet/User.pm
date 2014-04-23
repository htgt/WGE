use utf8;
package WGE::Model::Schema::ResultSet::User;

use base 'DBIx::Class::ResultSet';

sub auto_create {
    my ( $self, $col_data ) = @_;

    my $new = $self->create($col_data);

    $self->result_source->schema->clear_cached_constraint_method('existing_user');
    return $new;
}

1;