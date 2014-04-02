package WGE::Controller::Authentication;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use WGE::Util::OAuthHelper;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

WGE::Controller::Authentication - Controller to handle user authentication

=cut

sub login :Path('/login') :Args(0) {
    my ( $self, $c ) = @_;

    # FIXME: need to generate proper random number to use as state
    my $state = $c->sessionid;
    $c->session->{state} = $state;

    # Redirect user to google to authenticate
    # After login the user will be redirected to /set_user
    my $oauth_helper = WGE::Util::OAuthHelper->new;
    my $url = $oauth_helper->generate_auth_url($state);
    $c->response->redirect($url);
    return;
}

sub set_user :Path('/set_user') :Args(0) {
	my ( $self, $c ) = @_;

    $c->log->debug("Attempting to authenticate");
    $c->authenticate($c->req->params,'oauth');
    $c->response->redirect('/');
    return;
}

sub logout :Path('logout') :Args(0) {
    my ( $self, $c ) = @_;

    $c->logout;

    $c->flash->{info_msg} = 'You have been logged out';
    $c->response->redirect('/');
    return;
}

1;