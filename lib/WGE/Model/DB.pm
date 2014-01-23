package WGE::Model::DB;

use Moose;
use Config::Any;
use File::stat;
use Carp qw(confess);
use Data::Dumper;
require WGE::Model::FormValidator;

use base qw/Catalyst::Model::DBIC::Schema/;

my ($CONNECT_INFO);

{
	my $filename = $ENV{WGE_DBCONNECT_CONFIG}
        or confess "WGE_DBCONNECT_CONFIG environment variable not set";
    my $st = stat($filename)
        or confess "stat '$filename': $!";

    my $config = Config::Any->load_files( { files => [$filename], use_ext => 1, flatten_to_hash => 1 } );
    my $db_config = $config->{$filename}->{ $ENV{WGE_DB} }
        or confess "No db connection info found for ".$ENV{WGE_DB}." in $filename"; 
    $CONNECT_INFO = $db_config;
}
     
__PACKAGE__->config(
    schema_class => $CONNECT_INFO->{schema_class},
    connect_info =>  $CONNECT_INFO,
);

has form_validator => (
    is         => 'ro',
    isa        => 'WGE::Model::FormValidator',
    lazy_build => 1,
    handles    => ['check_params']
);

sub _build_form_validator {
    my $self = shift;

    return WGE::Model::FormValidator->new( model => $self );
}

sub schema{
    my $self = shift;

    return $self;
}
 
1;