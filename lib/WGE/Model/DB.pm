package WGE::Model::DB;

use Config::Any;
use File::stat;
use Carp qw(confess);
use Data::Dumper;
require WGE::Model::FormValidator;
use Log::Log4perl qw( :easy );
use Module::Pluggable::Object;

use base qw/Catalyst::Model::DBIC::Schema/;

my ($CONNECT_INFO, $FORM_VALIDATOR);

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

__PACKAGE__->config({
    schema_class => $CONNECT_INFO->{schema_class},
    connect_info =>  $CONNECT_INFO,
    traits => [ map { "+".$_ } Module::Pluggable::Object->new( search_path => [ 'WGE::Model::Plugin' ] )->plugins ],
});


sub check_params{
    my ($self, @args) = @_;

    $FORM_VALIDATOR ||= WGE::Model::FormValidator->new({model => $self});
    my $caller = ( caller(2) )[3];
    DEBUG "check_params caller: $caller";
    return $FORM_VALIDATOR->check_params(@args);
}

1;