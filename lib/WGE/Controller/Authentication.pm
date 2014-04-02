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

# FIXME: set this secret key somehwere secret
my $key = "test";

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

    # Check we have an auth code
    my $auth_code = $c->req->param('code');
    unless($auth_code){
        $c->flash->{error_msg} = "Login failed: no authoriziation code returned by google";
        $c->res->redirect('/');
        return;
    }

	# Check returned state and session state
    my $state = $c->req->param('state');
    unless ($state eq $c->session->{state}){
        $c->flash->{error_msg} = "Login failed: google authorization does not match user session";
        $c->res->redirect('/');
        return;
    }

	# Use auth code to fetch user information
    my $oauth_helper = WGE::Util::OAuthHelper->new;    
    my $profile;
    try{
        $profile = $oauth_helper->fetch_user_profile($auth_code);
    }
    catch($e){
        $c->flash->{error_msg} = "Login failed: could not get google user profile. $e";
        $c->res->redirect('/');
        return;
    }

    $c->log->debug("user profile: ",Dumper($profile));
    # Check email_verified == true
    $c->flash->{info_msg} = "Authenticated user ".$profile->{email};
    $c->res->redirect('/');
    return;

    #my $username = $oauth_request->email_address;

    #unless($username){
    #	$c->flash->{error_msg} = "Could not login...";
    #}

    # Find or create user in DB

    # Set user for session

    #$c->response->redirect('/');
}

sub logout :Path('logout') :Args(0) {
    my ( $self, $c ) = @_;

}

1;