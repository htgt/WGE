package WGE::Controller::REST;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::REST::VERSION = '0.049';
}
## use critic

use Moose;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

sub auto : Private {
    my ( $self, $c ) = @_;

    unless ( $c->user ) {
        $c->log->debug("Attempting to authenticate");
        my $username = delete $c->req->parameters->{ 'username' };
        my $password = delete $c->req->parameters->{ 'password' };

        my $authenticated = $c->authenticate( { username => $username, password => $password } );
        
        unless ( $authenticated ) {
            $self->status_bad_request(
                $c,
                message => "Could not authenticate. Username or password incorrect.",
            );
            return 0;
        }
    }

    return 1;
}

1;
