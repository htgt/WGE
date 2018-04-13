package WGE::Util::OffTargetServer;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::OffTargetServer::VERSION = '0.112';
}
## use critic


use Moose;
use LWP::UserAgent;
use MooseX::Types::URI qw( Uri );
use JSON;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use List::MoreUtils qw(uniq natatime);
use TryCatch;

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

    my $uri = URI->new($ENV{OFF_TARGET_SERVER_URL} || 'http://htgt.internal.sanger.ac.uk:8080/');
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
    die "No species provided" unless $params->{species};

    $ids = [ $ids ] unless ref $ids eq 'ARRAY'; #allow arrayref/scalar

    DEBUG("finding off targets for ", Dumper($ids));
    my $uri = $self->ots_server_uri( "/api/off_targets" );
    $uri->query_form( species => $params->{species}, ids => join ",", @{ $ids } );

    return $self->_get_json( $uri, $params->{as_string} );
}

sub find_off_targets_by_seq {
    my ( $self, $params ) = @_;

    my $seq = $params->{sequence};
    die "No sequence provided\n" unless $params->{sequence};

    die "Sequence must be 20 bases long\n" unless length($seq) == 20;

    my $pam_right = $params->{pam_right};
    die "Crispr pam_right orientation must be provided\n" unless defined($params->{pam_right});

    die "Invalid pam_right orientation provided, must be true or false\n" unless ($params->{pam_right} eq 'true' || $params->{pam_right} eq 'false');

    my $uri = $self->ots_server_uri( "/api/off_targets_by_seq" );
    $uri->query_form( species => $params->{species}, seq => $seq, pam_right => $pam_right );

    return $self->_get_json( $uri, $params->{as_string} );
}


sub update_off_targets {
    my ( $self, $model, $params ) = @_;

    my %all_results;

    # Go through list of IDs 10 at a time
    my @all_ids = uniq @{ $params->{ids} };
    my $it = natatime 10, @all_ids;
    while (my @ids = $it->()){
        # check and update crispr_ots_pending table to avoid repeat submissions
        my $new_ids = $self->_get_new_and_set_pending($model,\@ids);
        $params->{ids} = $new_ids;
        next unless @$new_ids;

        my $results;
        try {
            $results = $self->find_off_targets( $params );
        }
        catch ($e){
            $self->_set_to_not_pending($model,$new_ids);
            die "Could not do crispr off-target search - $e";
        }

        $self->_set_to_not_pending($model,$new_ids);

        while ( my ( $id, $data ) = each %{ $results } ) {

            if($id eq "error"){
                die "Off-target server error: ".$data;
            }

            $all_results{$id} = $data;

            my %update = ( off_target_summary => $data->{off_target_summary} );
            #dont update the off targets if we didnt get any (because the crispr has >5000)
            $update{off_target_ids} = $data->{off_targets} if @{ $data->{off_targets} } > 0;

            my $crispr = $model->schema->resultset('Crispr')->find( $id );
            $crispr->update( \%update );
        }
    }

    return \%all_results;
}

# Methods to check and alter the CrisprOtPending status table
sub _get_new_and_set_pending{
    my ($self, $model, $ids) = @_;

    # Set IDs to pending as soon as we determine they are not already pending
    # to avoid clashes
    my @new_ids;
    foreach my $id (@{ $ids || [] }){
        if($model->schema->resultset('CrisprOtPending')->find($id)){
            next;
        }
        else{
            $model->schema->resultset('CrisprOtPending')->create({ crispr_id => $id });
            push @new_ids, $id;
        }
    }
    return \@new_ids;
}

sub _ids_not_pending{
    my ($self, $model, $ids) = @_;
    my @new_ids;
    foreach my $id (@{ $ids || [] }){
        if($model->schema->resultset('CrisprOtPending')->find($id)){
            next;
        }
        else{
            push @new_ids, $id;
        }
    }
    return \@new_ids;
}

sub _set_to_pending{
    my ($self, $model, $ids) = @_;
    foreach my $id (@{ $ids || [] }){
        $model->schema->resultset('CrisprOtPending')->create({ crispr_id => $id });
    }
    return;
}

sub _set_to_not_pending{
    my ($self, $model, $ids) = @_;
    foreach my $id (@{ $ids || [] }){
        if(my $pending = $model->schema->resultset('CrisprOtPending')->find($id)){
            $pending->delete();
        }
    }
    return;
}

1;
