package WGE::Controller::REST::Crispr;

use Moose;
use Try::Tiny;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

sub crispr : Path( '/api/crispr' ) : Args(0) :ActionClass( 'REST' ) {}

sub crispr_GET{
    my ($self, $c) = @_;

    $c->assert_user_roles('read');

    my $crispr = $c->model('DB')->resultset('Crispr')->find({ id => $c->req->param('id') });

    return $self->status_ok( $c, entity => $crispr->as_hash );
}

sub crispr_POST{
    my ($self, $c) = @_;

    $c->assert_user_roles('edit');
    my @update_cols = qw(off_targets off_target_summary);

    my $params = $c->req->params;

    my $crispr = $c->model->resultset('Crispr')->find($params->{id});
    my %update_params = map { $_ => $params->{$_} } grep { exists $params->{$_} } @update_cols;

    $crispr->update(\%update_params) or die $!;

    return $self->status_ok( $c, entity => $crispr->as_hash );
}

1;
