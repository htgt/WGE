package WGE::Controller::REST::Species;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::REST::Species::VERSION = '0.039';
}
## use critic


use Moose;
use Try::Tiny;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

sub get_all_species :Path( '/api/get_all_species' ) :Args( 0 ) :ActionClass( 'REST' ) {}

sub get_all_species_GET {
    my ( $self, $c ) = @_;

    $c->assert_user_roles('read');

    #map numerical id to text id for lims2
    my %data = map { $_->numerical_id, $_->id } $c->model('DB')->resultset("Species")->search;

    return $self->status_ok( $c, entity => \%data)
}

1;