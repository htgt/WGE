package WGE::Controller::REST::Crispr;

use Moose;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

sub crispr : Path( '/api/crispr' ) : Args(0) :ActionClass( 'REST' ) {}

sub crispr_GET{
    my ($self, $c) = @_;

    $c->assert_user_roles('read');

    my $crispr = $c->model('DB')->resultset('Crispr')->find($c->req->param('id'));

    return $self->status_ok( $c, entity => $crispr->as_hash );
}

sub crispr_POST{
    my ($self, $c) = @_;

    $c->assert_user_roles('edit');

}

sub crispr_pair : Path( '/api/crispr_pair') : Args(0) :ActionClass( 'REST' ) {}

sub crispr_pair_GET{
    my ($self, $c) = @_;

    $c->assert_user_roles('read');

    my $crispr_pair = $c->model('DB')->resultset('CrisprPair')->find($c->req->param('id'));
    return $self->status_ok( $c, entity => $crispr_pair->as_hash );
}

sub crispr_pair_POST{
    my ($self, $c) = @_;

    $c->assert_user_roles('edit');
}

1;