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
    default  => sub { dir( $Bin, "data") },
);

has appdir => (
    is => 'rw',
    required => 1,
    default => sub { dir( $Bin, '../' ) },
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

sub fixture_data {
    my ( $self, $name ) = @_;

    #add .yaml extension if its not there already
    if ( $name !~ /\.yaml$/ ) { 
        $name .= ".yaml";
    }

    return LoadFile( $self->fixture_folder->file( $name )->stringify );
}

#accepts an optional array of hashrefs of { file => filename, resultset => name }
sub load_fixtures {
    my ( $self, $fixtures ) = @_;

    #default behaviour is to load ALL
    unless ( defined $fixtures ) {
        $fixtures = [
            { file => 'genes',   resultset => 'Gene'       , delete_related => [qw(Exon)]},
            { file => 'crisprs', resultset => 'Crispr'     , delete_related => [qw(CrisprsHuman CrisprsMouse)]},
        ];
    }

    #we want to ideally store how many were in each file so we can
    #verify they all went in.

    for my $fixture ( @{ $fixtures } ) {
        my $data = $self->fixture_data( $fixture->{file} );
        
        # Clear out old fixture data before loading new
        if (my $related = $fixture->{delete_related}){
            foreach my $table (@$related){
        	    $self->schema->resultset( $table )->delete_all;
            }
        }
        $self->schema->resultset( $fixture->{resultset} )->delete_all;
        $self->schema->resultset( $fixture->{resultset} )->load_from_hash( $data, 1 );
    }

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