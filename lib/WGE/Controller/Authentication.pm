package WGE::Controller::Authentication;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::Authentication::VERSION = '0.057';
}
## use critic

use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use WGE::Util::OAuthHelper;
use Data::Random qw(rand_chars);

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

    # Generate random string to verify that google's response
    # relates to this session
    my $state = rand_chars( set => 'alphanumeric', min => 30, max => 30);
    $c->session->{state} = $state;
    $c->session->{login_referer} = $c->req->referer;

    # Redirect user to google to authenticate
    # After login the user will be redirected to /set_user
    my $oauth_helper = WGE::Util::OAuthHelper->new;
    my $url = $oauth_helper->generate_auth_url($state, $c->uri_for('/set_user'));
    $c->response->redirect($url);
    return;
}

sub set_user :Path('/set_user') :Args(0) {
	my ( $self, $c ) = @_;

    $c->log->debug("Attempting to authenticate");
    $c->authenticate($c->req->params,'oauth');
    $c->response->redirect($c->session->{login_referer} || $c->uri_for('/'));
    return;
}

sub logout :Path('logout') :Args(0) {
    my ( $self, $c ) = @_;

    $c->logout;

    $c->flash->{info_msg} = 'You have been logged out';
    $c->response->redirect($c->uri_for('/'));
    return;
}

1;