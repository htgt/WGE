package WGE;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application.
#
# Note that ORDERING IS IMPORTANT here as plugins are initialized in order,
# therefore you almost certainly want to keep ConfigLoader at the head of the
# list if you're using it.
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    ConfigLoader
    Static::Simple
    Authentication
    Authorization::Roles
    Session
    Session::Store::FastMmap
    Session::State::Cookie    
/;

use Log::Log4perl::Catalyst;

extends 'Catalyst';

our $VERSION = '0.01';

__PACKAGE__->log(Log::Log4perl::Catalyst->new( $ENV{WGE_LOG4PERL_CONFIG} ));

# Configure the application.
#
# Note that settings in wge.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'WGE',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    enable_catalyst_header => 1, # Send X-Catalyst header
    using_frontend_proxy => 1,
    default_model => 'DB',
    default_view => 'Web',
    'View::Web' => {
        INCLUDE_PATH => [
            __PACKAGE__->path_to( 'root' ),
            __PACKAGE__->path_to( 'root', 'gibson' ),
            __PACKAGE__->path_to( 'root', 'site' ),          
            $ENV{SHARED_WEBAPP_TT_DIR} || '/opt/t87/global/software/perl/lib/perl5/WebAppCommon/shared_templates',
            ],
    },
    'View::JSON' => { expose_stash => 'json_data' },
    'View::CSV' => { sep_char => "\t", suffix => "tsv" },
    'static' => {
        include_path => [
            $ENV{SHARED_WEBAPP_STATIC_DIR} || '/opt/t87/global/software/perl/lib/perl5/WebAppCommon/shared_static',
            __PACKAGE__->path_to( 'root' ),
        ],
    },
    'Plugin::Session' => {
        storage => $ENV{WGE_SESSION_STORE} || '/tmp/wge',
    },
    authentication => {
        default_realm => 'rest_client',
        realms => {
            rest_client => {
                credential => {
                    class => 'Password',
                    password_field => 'password',
                    password_type => 'salted_hash',
                    password_salt_len => '4',
                },
                store => {
                    class => 'Minimal',
                    users => {
                        rest_user => {
                           password => "{SSHA}K5f/ygKbkRk/GonQzGCjv5gsSS4iuCX+",
                           roles => [qw/read edit/],
                        },
                        guest => {
                            password => "{SSHA}psAZrBkzjQcJIyDb4K5SpSjQLDdPiWU0",
                            roles => [qw/read/],
                        },
                    }
                }
            },
            oauth => {
                auto_create_user => 1,
                credential => {
                    class          => 'OAuth2',
                    username_field => 'name',
                },
                store => {
                    class         => 'DBIx::Class',
                    user_model    => 'DB::User',
                    id_field      => 'name',
                },                
            }            
        }
    }
);

# Start the application
__PACKAGE__->setup();


=head1 NAME

WGE - Catalyst based application

=head1 SYNOPSIS

    script/wge_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<WGE::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Anna Farne

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
