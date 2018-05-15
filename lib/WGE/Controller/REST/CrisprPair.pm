package WGE::Controller::REST::CrisprPair;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::REST::CrisprPair::VERSION = '0.114';
}
## use critic


use Moose;
use Try::Tiny;
use namespace::autoclean;
use Data::Dumper;
use WGE::Util::FindPairs;

#add a has pair_finder instead of instantiating new each time

BEGIN { extends 'Catalyst::Controller::REST' }

sub crispr_pair : Path( '/api/crispr_pair' ) : Args(0) :ActionClass( 'REST' ) {}

sub crispr_pair_GET {
    my ( $self, $c ) = @_;

    $c->assert_user_roles('read');

    my $pair = $c->model('DB')->resultset('CrisprPair')->find( 
        {
            left_id => $c->req->param('left_id'),
            right_id => $c->req->param('right_id'),
        }
    );

    return $self->status_ok( $c, entity => $pair->as_hash );
}

sub crispr_pair_POST {
    my ( $self, $c ) = @_;

    $c->assert_user_roles('edit');

    my $pair = $c->model('DB')->resultset('CrisprPair')->update_or_create(
        $c->req->data,
        { key => 'primary' }
    ) or die $!;

    return $self->status_ok( $c, entity => $pair->as_hash );
}

sub find_or_create_crispr_pair :Path( '/api/find_or_create_crispr_pair' ) :ActionClass( 'REST' ) {}

sub find_or_create_crispr_pair_GET {
    my ( $self, $c ) = @_;

    $c->assert_user_roles('edit');

    my ( $pair, $crisprs, $error );
    try {
        ( $pair, $crisprs ) = $c->model('DB')->find_or_create_crispr_pair( $c->req->params );
    }
    catch {
        $error = $_;
    };

    return $error ? $self->status_bad_request( $c, message => $error ) 
                  : $self->status_ok( $c, entity => $pair->as_hash );
}

sub calculate_offs : Path( '/api/calculate_pair_off_targets' ) : Args(0) :ActionClass( 'REST' ) {}

sub calculate_offs_GET {
    my ( $self, $c ) = @_;

    $c->assert_user_roles('edit');

    my $pair = $c->model('DB')->resultset('CrisprPair')->find( 
        {
            left_id  => $c->req->param('left_id'),
            right_id => $c->req->param('right_id'),
        }
    );

    my $total_offs = $pair->calculate_off_targets;

    return $self->status_ok( $c, entity => $pair->as_hash );
}

1;
