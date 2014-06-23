package WGE::Util::OffTargetServer;

use Moose;
use LWP::UserAgent;
use MooseX::Types::URI qw( Uri );
use JSON;
use Data::Dumper;
use Log::Log4perl qw(:easy);

BEGIN {
    #try not to override the logger
    unless ( Log::Log4perl->initialized ) {
        Log::Log4perl->easy_init( { level => $DEBUG } );
    }
}

has ua => (
    is         => 'ro',
    isa        => 'LWP::UserAgent',
    lazy_build => 1,
    handles    => [ 'get' ]
);

sub _build_ua {
    return LWP::UserAgent->new();
}

sub ots_server_uri {
    my ( $self, $path ) = @_;

    my $uri = URI->new($ENV{OFF_TARGET_SERVER_URL} || 'http://t87-batch-farm3.internal.sanger.ac.uk:8080/');
    $uri->path( $path );

    return $uri;
}

sub _get_json {
    my ( $self, $uri, $as_string ) = @_;

    my $response = $self->ua->get( $uri );
    unless ( $response->is_success ) {
        die "Off target server query failed: " . $response->message;
    }

    return $as_string ? $response->content : decode_json( $response->content );
}

sub search_by_seq {
    my ( $self, $params ) = @_;

    my $uri = $self->ots_server_uri( "api/search" );
    $uri->query_form( seq => $params->{sequence}, pam_right => $params->{pam_right}, species => $params->{species} );

    return $self->_get_json( $uri, $params->{as_string} );
}

sub find_off_targets {
    my ( $self, $params ) = @_;

    my $ids = $params->{ids};

    $ids = [ $ids ] unless ref $ids eq 'ARRAY'; #allow arrayref/scalar

    DEBUG("finding off targets for ", Dumper($ids));
    my $uri = $self->ots_server_uri( "/api/off_targets" );
    $uri->query_form( ids => join ",", @{ $ids } );

    return $self->_get_json( $uri, $params->{as_string} );
}

sub update_off_targets {
    my ( $self, $model, $params ) = @_;

    my $results = $self->find_off_targets( $params );

    DEBUG("Results:");
    DEBUG(Dumper($results));

    while ( my ( $id, $data ) = each %{ $results } ) {

        my %update = ( off_target_summary => $data->{off_target_summary} );
        #dont update the off targets if we didnt get any (because the crispr has >5000)
        $update{off_target_ids} = $data->{off_targets} if @{ $data->{off_targets} } > 0;

        my $crispr = $model->schema->resultset('Crispr')->find( $id );
        $crispr->update( \%update );
    }

    return $results;
}

1;