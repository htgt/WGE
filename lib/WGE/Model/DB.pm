package WGE::Model::DB;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::DB::VERSION = '0.042';
}
## use critic


use strict;
use warnings;

use Moose;
extends qw( Catalyst::Model::DBIC::Schema );

use Config::Any;
use File::stat;
use Carp qw(confess);
use Data::Dumper;
require WGE::Model::FormValidator;
use Log::Log4perl qw( :easy );
use Module::Pluggable::Object;
use Data::Dump qw( pp );

has form_validator => (
    is         => 'rw',
    isa        => 'WGE::Model::FormValidator',
    lazy_build => 1,
);

sub _build_form_validator {
    return WGE::Model::FormValidator->new( { model => shift } );
}

#load config file and set the required schema_class and connect_info attrs
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    #make sure config file is set and the file actually exists
    my $config_file = $ENV{WGE_DBCONNECT_CONFIG};
    my $db_name     = $ENV{WGE_DB};

    confess "WGE_DBCONNECT_CONFIG must be set"  unless $config_file;
    confess "Could not access $config_file: $!" unless stat $config_file;
    confess "WGE_DB must be set" unless $db_name;

    my $config = Config::Any->load_files(
        { files => [ $config_file ], use_ext => 1, flatten_to_hash => 1 }
    );

    my $db_config = $config->{$config_file}->{$db_name}
        or confess "No db connection info found for $db_name in $config_file";

    #call the original buildargs to process arguments,
    #which returns a hashref
    my $data = $class->$orig( @_ );

    #set the two required attrs from our config
    $data->{schema_class} ||= $db_config->{schema_class};
    $data->{connect_info} ||= $db_config;

    return $data;
};

sub clear_schema {
    my ( $self ) = @_;

    $self->schema->storage->disconnect;

    return;
}

sub txn_do {
    my ( $self, $code_ref, @args ) = @_;

    return $self->schema->txn_do( $code_ref, $self, @args );
}

#can't use handles because we don't define $self->schema...
sub txn_rollback {
    my ( $self, @args ) = @_;

    return $self->schema->txn_rollback( @args );
}

sub check_params {
    my ( $self, @args ) = @_;

    #get the subroutnie name that called us
    my $caller = ( caller(2) )[3];
    $self->log->debug( "check_params caller: $caller" );
    return $self->form_validator->check_params( @args );
}

sub clear_cached_constraint_method {
    my ( $self, $constraint_name ) = @_;

    if ( $self->form_validator->has_cached_constraint_method($constraint_name) ) {
        $self->form_validator->delete_cached_constraint_method($constraint_name);
    }

    return;
}

## no critic(RequireFinalReturn)
sub retrieve {
    my ( $self, $entity_class, $search_params, $search_opts ) = @_;

    $search_opts ||= {};

    my @objects = $self->schema->resultset($entity_class)->search( $search_params, $search_opts );

    if ( @objects == 1 ) {
        return $objects[0];
    }
    elsif ( @objects == 0 ) {
        $self->throw( NotFound => { entity_class => $entity_class, search_params => $search_params } );
    }
    else {
        $self->throw( Implementation => "Retrieval of $entity_class returned " . @objects . " objects" );
    }
}
## use critic

## no critic(RequireFinalReturn)
sub throw {
    my ( $self, $error_class, $args ) = @_;

    if ( $error_class !~ /::/ ) {
        $error_class = 'LIMS2::Exception::' . $error_class;
    }

    eval "require $error_class"
        or confess "Load $error_class: $!";

    my $err = $error_class->new($args);

    $self->log->error( $err->as_string );

    $err->throw;
}
## use critic

sub trace {
    my ( $self, @args ) = @_;

    if ( $self->log->is_trace ) {
        my $mesg = join "\n", map { ref $_ ? pp( $_ ) : $_ } @args;
        $self->log->trace( $mesg );
    }

    return;
}

sub _chr_id_for {
    my ( $self, $assembly_id, $chr_name ) = @_;

    my $chr = $self->schema->resultset('Chromosome')->find(
        {
            'me.name'       => $chr_name,
            'assemblies.id' => $assembly_id
        },
        {
            join => { 'species' => 'assemblies' }
        }
    );

    if ( ! defined $chr ) {
        $self->throw( Validation => "No chromosome $chr_name found for assembly $assembly_id" );
    }

    return $chr->id;
}

#get all plugins
my @plugins = Module::Pluggable::Object->new(
    search_path => [ 'WebAppCommon::Plugin', 'WGE::Model::Plugin' ]
)->plugins;

#load roles
with qw( MooseX::Log::Log4perl ), @plugins;

1;
