package WGE::Controller::REST::Design;

use Moose;
use Try::Tiny;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

sub design : Path( '/api/design' ) : Args(0) :ActionClass( 'REST' ) {}

sub design_GET{
     my ($self, $c) = @_;

     my $design = $c->model->resultset('Design')->find({ id => $c->req->param('id') });

     return $self->status_ok( $c, entity => $design->as_hash );
}

sub design_POST{
    my ( $self, $c ) = @_;

    $c->assert_user_roles('edit');

    my $design = $c->model->txn_do(
        sub {
            shift->create_design( $c->request->data );
        }
    );

    return $self->status_created(
        $c,
        location => $c->uri_for( '/api/design', { id => $design->id } ),
        entity   => $design
    );
}

1;
