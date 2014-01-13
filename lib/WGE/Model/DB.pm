package WGE::Model::DB;

use Config::Any;
use File::stat;
use Carp qw(confess);
use Data::Dumper;

use base qw/Catalyst::Model::DBIC::Schema/;

my ($CONNECT_INFO);

{
	my $filename = $ENV{LIMS2_DBCONNECT_CONFIG}
        or confess "LIMS2_DBCONNECT_CONFIG environment variable not set";
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
 
1;