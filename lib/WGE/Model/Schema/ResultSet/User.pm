use utf8;
package WGE::Model::Schema::ResultSet::User;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub auto_create {
    my ( $self, $col_data ) = @_;

    my $new = $self->create($col_data);

    return $new;
}

1;
