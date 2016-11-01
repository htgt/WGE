package WGE::Controller::REST;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::REST::VERSION = '0.101';
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
        #my $username = delete $c->req->parameters->{ 'username' };
        #my $password = delete $c->req->parameters->{ 'password' };
        my $key = delete $c->req->headers->{pass};

        my $_conf = Config::Tiny->read($ENV{LIMS2_REST_CLIENT_CONFIG});
        my $serial = Data::Serializer->new();
        $serial = Data::Serializer->new(
            serializer  => 'Data::Dumper',
            digester    => 'SHA-256',
            cipher      => 'Blowfish',
            secret      => $_conf->{api}->{transport},
            compress    => 0,
        );

        my $frozen = $serial->thaw($key);

        my $authenticated = $c->authenticate( { access_key => $frozen->{access}, secret_key => $frozen->{secret} }, 'rest' );
        
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
