package Test::WGE;

# Always use the test instance of the database
BEGIN{
	my $test_db_profile = $ENV{WGE_TEST_DB} || "WGE_TEST";
	print "** Using $test_db_profile database connection for tests **\n";
	$ENV{WGE_DB} = $test_db_profile;
}

use Moose;
use FindBin qw( $Bin ); #this will be the t folder
use Path::Class;
use YAML qw( LoadFile );
use URI;
use Try::Tiny;

use WGE;
use WGE::Model::DB;
use Test::WWW::Mechanize::Catalyst;
use JSON qw(decode_json);
use Catalyst::Authentication::Credential::OAuth2;
use Test::MockModule;


# Hide debug output during tests
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $OFF} );

has schema => (
    is => 'rw',
    lazy_build => 1, #not always required
);

has mech => (
    is       => 'rw',
    required => 1,
    builder  => '_build_mech',
);

has fixture_folder => (
    is       => 'rw',
    required => 1,
    default  => sub { dir( $Bin, "fixtures") },
);

has data_folder => (
    is       => 'rw',
    required => 1,
    default  => sub { dir( $Bin, "data") },
);

has appdir => (
    is => 'rw',
    required => 1,
    default => sub { dir( $Bin, '../' ) },
);

has authenticated_mech => (
    is       => 'rw',
    required => 1,
    builder  => '_build_authenticated_mech',
);

sub _build_mech {
    my $self = shift;

    #extend Test::WWW::Mechanize with error_ok method. this is probably a bad idea
    {
        package Test::WWW::Mechanize;

        sub error_ok {
            my $self = shift;

            my ($url, $desc, %opts) = $self->_unpack_args( 'GET', @_ );

            $self->get( $url, %opts );
            my $ok = ! $self->success; #basically just invert success

            $ok = $self->_maybe_lint( $ok, $desc );

            return $ok;
        }
    }

    return Test::WWW::Mechanize::Catalyst->new(
        catalyst_app => 'WGE',
    );
}

sub _build_authenticated_mech {
    my $self = shift;

    # Override the authenticate method so it does not try to access google
    my $module = new Test::MockModule('Catalyst::Authentication::Credential::OAuth2');
    $module->mock('authenticate' => sub {
        my ($self, $c, $realm) = @_;
        return $realm->find_user(
            { name => 'test_user@gmail.com' },
            $c
        );
    });

    # Build a new mech object and access set_user controller to trigger authentication
    my $mech = $self->_build_mech;
    $mech->get('/set_user');

    return $mech;
}

#note that you must run load_fixtures manually.
sub _build_schema {
    my $self = shift;

    my $schema;

    try {
        $schema = WGE::Model::DB->new();
    };

    #schema was called before the mech has been initialised so the config
    #isn't loaded for some reason. force the mech to initialize and re-try.
    unless ( $schema ) {
        print "Couldn't load test schema; initialising mech and re-trying.";
        $self->mech->get('/');
        $schema = WGE::Model::DB->new();
    }

    #load the schema
    #$schema->deploy;

    return $schema;
}

sub json_data {
    my ($self, $name) = @_;
    my $path = $self->data_folder->file($name)->stringify;
    open (my $fh, "<", $path )
        or die "Cannot open json data file $path";
    return decode_json(<$fh>);
}

sub load_fixtures {
    my $self = shift;

    # clear database using clean_db.sql then load fixture sql files
    #my @sql_files = qw(clean_db reference_fixtures design_fixtures);
    my @sql_files = qw(clean_db reference_fixtures );

    foreach my $file (@sql_files){
        my $file_name = $file.".sql";
        my $fh = $self->fixture_folder->file($file_name)->open;
        my $sql = join " ", <$fh>;
        $self->schema->storage->dbh->do($sql);
    }

    # load human and mouse crispr.csv fixtures in correct order
    foreach my $species ( qw(human mouse) ){
        foreach my $table ( qw(genes exons) ){
            my $file_name = $species . "_" . $table . ".csv";
            my $fh = $self->fixture_folder->file($file_name)->open;
            $self->pg_copy_fh_to_table($fh, $table);

        }

        foreach my $table ( qw(crisprs crispr_pairs) ){
            my $file_name = $species . "_" . $table . ".csv";
            my $child_table = $table . "_" . $species;
            my $fh = $self->fixture_folder->file($file_name)->open;
            $self->pg_copy_fh_to_table($fh, $child_table);
        }

    }
    return;
}

sub pg_copy_fh_to_table{
    my ( $self, $fh, $table_name ) = @_;

    my $dbh = $self->schema->storage->dbh;
    $dbh->do("COPY $table_name from STDIN with delimiter ';' csv header");
    foreach my $line(<$fh>){
        $dbh->pg_putcopydata($line);
    }
    $dbh->pg_putcopyend();
    return;
}

sub add_ajax_headers {
    my ( $self ) = @_;

    $self->mech->add_header(
        'X-Requested-With' => 'XMLHttpRequest',
        'Content-Type'     => 'application/json',
        'Accept'           => 'application/json, text/javascript, */*'
    );
}

sub delete_ajax_headers {
    my ( $self ) = @_;

    $self->mech->delete_header(
        'X-Requested-With',
        'Content-Type',
        'Accept',
    );
}

#build a uri with get parameters
sub get_uri {
    my ( $self, $url, $params ) = @_;

    my $uri = URI->new( $url );
    $uri->query_form( $params );

    return $uri;
}

1;