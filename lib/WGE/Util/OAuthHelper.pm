package WGE::Util::OAuthHelper;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::OAuthHelper::VERSION = '0.040';
}
## use critic


use strict;
use warnings FATAL => 'all';

use Moose;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;
use Data::Dumper;
use namespace::autoclean;
use MooseX::ClassAttribute;
use MIME::Base64 qw(decode_base64);
use Log::Log4perl qw(:easy);

BEGIN {
    #try not to override the logger
    unless ( Log::Log4perl->initialized ) {
        Log::Log4perl->easy_init( { level => $DEBUG } );
    }
}

class_has google_config => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
);

class_has client_config => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
);

sub _build_google_config{
    my $config_url = 'https://accounts.google.com/.well-known/openid-configuration';
    DEBUG("Fetching google config from config_url");
    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(verify_hostname => 0, SSL_Debug => 0);
    $ua->proxy('https', $ENV{HTTPS_PROXY});
    my $response = $ua->get($config_url);
    ## FIXME: Check for download failure
    my $json = decode_json($response->content);
    return $json;
}

sub _build_client_config{
    my $config_file = $ENV{WGE_OAUTH_CLIENT};
    DEBUG("Loading OAuth client info from $config_file");
    open (my $fh, "<", $config_file) or die "Could not open OAuth config file $config_file - $!";
    my $json = decode_json(<$fh>);
    return $json->{web};
}

sub generate_auth_url{
    my ($self, $state, $redirect) = @_;

    my %params = (
        client_id     => $self->client_config->{client_id},
        response_type => 'code',
        scope         => 'email',
        redirect_uri  => $redirect,
        state         => $state,
        prompt        => 'select_account',
    );

    my $url_base = $self->google_config->{authorization_endpoint};
    return _build_url($url_base,\%params);
}

sub fetch_user_profile{
    my ($self, $code, $redirect) = @_;

    my $token_url = $self->google_config->{token_endpoint};
    my %params = (
        code          => $code,
        client_id     => $self->client_config->{client_id},
        client_secret => $self->client_config->{client_secret},
        redirect_uri  => $redirect,
        grant_type    => 'authorization_code',
    );

    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(verify_hostname => 0, SSL_Debug => 0);
    $ua->proxy('https', $ENV{HTTPS_PROXY});
    my $response = $ua->request(POST $token_url, \%params);

    unless($response->is_success){
        die "Could not retrieve google credentials: "
            .$response->status_line.", ".$response->content;
    }
    my $json = decode_json($response->content);
    my $id_token = $json->{id_token};

    my @a = split '\.', $id_token;
    my $profile = decode_base64url($a[1]);
    my $p = decode_json($profile);

    return $p;
}

=head _build_url

Construct a URL string from URL base and hashref of parameters

=cut

sub _build_url {
    my ( $url, $params ) = @_;
   
    my @param_strings;
    if($params){
        while (my ($key, $value) = each %{ $params } ){
            push @param_strings, $key."=".$value;
        }
        $url .= "?";
        $url .= join "&", @param_strings;
    }

    return $url;
}

####################################################
# Taken from newer MIME::Base64
# In order to support older version of MIME::Base64
####################################################
sub decode_base64url {
    my $s = shift;
    $s =~ tr[-_][+/];
    $s .= '=' while length($s) % 4;
    return decode_base64($s);
}
1;
