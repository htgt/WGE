package WGE::Controller::REST::Design;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::REST::Design::VERSION = '0.050';
}
## use critic


use Moose;
use Try::Tiny;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

# Design and DesignAttempt create/update methods
# are defined in WebAppCommon::Plugin::Design

sub design : Path( '/api/design' ) : Args(0) :ActionClass( 'REST' ) {}

sub design_GET{
     my ($self, $c) = @_;

     my $design = $c->model->resultset('Design')->find({ id => $c->req->param('id') });

     my $supress_relations = 1;
     if (defined $c->req->param('supress_relations') ) {
        $supress_relations = $c->req->param('supress_relations');
     }

     return $self->status_ok( $c, entity => $design->as_hash($supress_relations) );
}

sub design_POST{
    my ( $self, $c ) = @_;

    $c->assert_user_roles('edit');

    my $design = $c->model->txn_do(
        sub {
            shift->c_create_design( $c->request->data );
        }
    );

    return $self->status_created(
        $c,
        location => $c->uri_for( '/api/design', { id => $design->id } ),
        entity   => $design->as_hash(1)
    );
}

sub design_attempt : Path( '/api/design_attempt' ) : Args(0) :ActionClass( 'REST' ) {
}

=head2 GET /api/design_attempt

Retrieve a design attempt by id.

=cut
sub design_attempt_GET {
    my ( $self, $c ) = @_;

    $c->assert_user_roles('read');

    my $design_attempt = $c->model->c_retrieve_design_attempt({id => $c->req->param('id')});

    return $self->status_ok( $c, entity => $design_attempt->as_hash({ json_as_hash => 1 }) );
}

=head2 POST

Create a design attempt

=cut
sub design_attempt_POST {
    my ( $self, $c ) = @_;

    $c->assert_user_roles('edit');

    my $design_attempt = $c->model->txn_do(
        sub {
            shift->c_create_design_attempt( $c->request->data );
        }
    );

    return $self->status_created(
        $c,
        location => $c->uri_for( '/api/design_attempt', { id => $design_attempt->id } ),
        entity   => $design_attempt->as_hash({ json_as_hash => 1 }),
    );
}

=head2 PUT

Update a design attempt

=cut
sub design_attempt_PUT {
    my ( $self, $c ) = @_;

    $c->assert_user_roles('edit');

    my $design_attempt = $c->model->txn_do(
        sub {
            shift->c_update_design_attempt( $c->request->data );
        }
    );

    return $self->status_created(
        $c,
        location => $c->uri_for( '/api/design_attempt', { id => $design_attempt->id } ),
        entity   => $design_attempt->as_hash({ json_as_hash => 1 }),
    );
}

1;
