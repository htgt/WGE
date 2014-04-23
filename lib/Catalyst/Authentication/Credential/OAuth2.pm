package Catalyst::Authentication::Credential::OAuth2;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $Catalyst::Authentication::Credential::OAuth2::VERSION = '0.013';
}
## use critic

use base qw/Catalyst::Authentication::Credential/;

use strict;
use warnings FATAL => 'all';

use TryCatch;
use Data::Dumper;
use WGE::Util::OAuthHelper;

sub new {
    my ($class, $config, $app, $realm) = @_;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub authenticate {
    my ( $self, $c, $realm, $authinfo ) = @_;

    # Check we have an auth code
    my $auth_code = $authinfo->{code};
    unless($auth_code){
        $c->flash->{error_msg} = "Login failed: no authoriziation code returned by google";
        return;
    }

	# Check returned state and session state
    my $state = $authinfo->{state};
    unless ($state eq $c->session->{state}){
        $c->flash->{error_msg} = "Login failed: google authorization does not match user session";
        return;
    }

	# Use auth code to fetch user information
    my $oauth_helper = WGE::Util::OAuthHelper->new;    
    my $profile;
    try{
        $profile = $oauth_helper->fetch_user_profile($auth_code, $c->uri_for('/set_user'));
    }
    catch($e){
        $c->flash->{error_msg} = "Login failed: could not get google user profile. $e";
        return;
    }

    $c->log->debug("user profile: ",Dumper($profile));

    unless($profile->{email_verified}){
        $c->flash->{error_msg} = "Login failed: email address not verified for ".$profile->{email};
        return;
    }
    $c->flash->{info_msg} = "You are now logged in as ".$profile->{email};

    my $username = $profile->{email};
    my $user_obj = $realm->find_user(
        { name => $username },
        $c
    );
     
    unless ( $user_obj ) {
        $c->log->error( "User '$username' could not be created in WGE" );
        return;
    }
     
    #$user_obj->roles($self->default_roles);     
     
    return $user_obj;      
}

1;
