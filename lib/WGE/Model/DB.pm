package WGE::Model::DB;

use Config::Any;
use File::stat;
use Carp qw(confess);
use Data::Dumper;
require WGE::Model::FormValidator;
use Hash::MoreUtils qw(slice_def);
use Log::Log4perl qw( :easy );

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
     
__PACKAGE__->config(
    schema_class => $CONNECT_INFO->{schema_class},
    connect_info =>  $CONNECT_INFO,
);


sub check_params{
    my ($self, @args) = @_;

    $FORM_VALIDATOR ||= WGE::Model::FormValidator->new({model => $self});
    my $caller = ( caller(2) )[3];
    DEBUG "check_params caller: $caller";
    return $FORM_VALIDATOR->check_params(@args);
}

# FIXME: put this in a separate module. set up plugins like LIMS2?

sub pspec_create_design_attempt {
    return {
        design_parameters => { validate => 'json', optional => 1 },
        gene_id           => { validate => 'non_empty_string' },
        status            => { validate => 'non_empty_string', optional => 1 },
        fail              => { validate => 'json', optional => 1 },
        error             => { validate => 'non_empty_string', optional => 1 },
        design_ids        => { validate => 'non_empty_string', optional => 1 },
        species           => { validate => 'existing_species', rename => 'species_id' },
        created_at        => { validate => 'date_time', post_filter => 'parse_date_time', optional => 1 },
        created_by        => { validate => 'existing_user', post_filter => 'user_id_for'},
        comment           => { optional => 1 },
    }
}

sub create_design_attempt {
    my ( $self, $params ) = @_;

    my $validated_params = $self->check_params( $params, $self->pspec_create_design_attempt );

    my $design_attempt = $self->schema->resultset( 'DesignAttempt' )->create(
        {
            slice_def (
                $validated_params,
                qw ( design_parameters gene_id status fail error species_id
                     design_ids created_at created_by comment
                   )
            )
        }
    );
    DEBUG( 'Created design attempt ' . $design_attempt->id );

    return $design_attempt;
}

sub user_id_for{
    my ($self, $name) = @_;

    my $user = $self->schema->resultset('User')->find({ name => $name});
    return $user->id;
}

1;