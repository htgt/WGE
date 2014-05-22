package WGE::Controller::CrisprReports;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::CrisprReports::VERSION = '0.017';
}
## use critic

use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use IO::File;
use Bio::Perl qw( revcom_as_string );
use List::MoreUtils qw(any);

BEGIN { extends 'Catalyst::Controller' }

has pair_finder => (
    is         => 'ro',
    isa        => 'WGE::Util::FindPairs',
    lazy_build => 1,
);

sub _build_pair_finder {
    my $self = shift;

    return WGE::Util::FindPairs->new;
}

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

WGE::Controller::CrisprReports - Controller for Crispr report pages in WGE

=cut

sub crispr_report :Path('/crispr') :Args(1){
    my ( $self, $c, $crispr_id ) = @_;

    $c->log->info( "Finding crispr $crispr_id" );

    my $crispr;
    #do in a try in case an sql error/dbi is raised
    try {
        $crispr = $c->model('DB')->resultset('Crispr')->find( 
            { id => $crispr_id } 
        );
    }
    catch {
        $c->log->warn( $_ );
    };

    unless ( $crispr ) {
        $c->log->info( "Couldn't find crispr $crispr_id!" );
        $c->stash( error_msg => "$crispr_id is not a valid crispr ID" );
        return;
    }

    $c->log->info( "Stashing off target data" );

    my $crispr_hash = $crispr->as_hash( { with_offs => 1, always_pam_right => 1 } );
    my $fwd_seq = $crispr_hash->{pam_right} ? $crispr_hash->{seq} : revcom_as_string( $crispr_hash->{seq} );

    $c->stash(
        crispr         => $crispr_hash,
        crispr_fwd_seq => $fwd_seq,
        species        => $crispr->get_species,
    );

    if($c->user){
        $c->log->debug("Finding crispr bookmarks for ".$c->user->name);
        $c->stash->{is_bookmarked} = any { $_->crispr_id == $crispr_id } $c->user->user_crisprs;
    }

    return; 
}

sub crispr_bookmark_status :Path('/crispr_bookmark_status'){
    my ($self, $c, $crispr_id) = @_;
    if($c->user){
        if (grep { $_->crispr_id == $crispr_id } $c->user->user_crisprs){
            $c->stash->{json_data} = { is_bookmarked => 1 };
        }
        else{
            $c->stash->{json_data} = { is_bookmarked => 0 };
        }
    }
    else{
        $c->stash->{json_data} = { error => "Could not check crispr bookmark status - no logged in user"};
    }

    $c->forward('View::JSON');

    return;
}

sub crispr_pair_bookmark_status :Path('/crispr_pair_bookmark_status'){
    my ($self, $c, $pair_id) = @_;
    if($c->user){
        if (grep { $_->crispr_pair_id eq $pair_id } $c->user->user_crispr_pairs){
            $c->stash->{json_data} = { is_bookmarked => 1 };
        }
        else{
            $c->stash->{json_data} = { is_bookmarked => 0 };
        }
    }
    else{
        $c->stash->{json_data} = { error => "Could not check crispr pair bookmark status - no logged in user"};
    }

    $c->forward('View::JSON');

    return;
}

sub bookmark_crispr :Path('/bookmark_crispr'){
    my ( $self, $c, $crispr_id, $action ) = @_;

    if($c->user){
        try{
            $c->log->debug("$action bookmark for crispr $crispr_id");
            $c->model->bookmark_crispr({
                username  => $c->user->name,
                crispr_id => $crispr_id,
                action    => $action,
            });
            $c->stash->{json_data} = { message => "$action bookmark for crispr $crispr_id - done" };
        }
        catch($e){
            $c->stash->{json_data} = { error => "Could not $action bookmark for crispr $crispr_id - $e" };
        }
    }
    else{
        # error, no user logged in
        $c->stash->{json_data} = { error => "Could not $action crispr bookmark - no logged in user" };
    }

    $c->forward('View::JSON');

    return;
}

sub bookmark_crispr_pair :Path('bookmark_crispr_pair'){
    my ( $self, $c, $crispr_pair_id, $action ) = @_;

    my ( $left_id, $right_id ) = split '_', $crispr_pair_id;
    my $json_data = {};

    if($c->user){
        my $crispr_pair = $c->model->resultset('CrisprPair')->find( 
            { left_id => $left_id, right_id => $right_id  }
        );
        unless($crispr_pair){
            ## Find species
            my $species = $c->model->resultset('Crispr')->find({ id => $left_id })->get_species;
            ## Begin off target search so pair is added to db
            ## I'm assuming that if user wants to bookmark it they'll want off target info too
            $c->log->debug("Starting off-target search for pair $crispr_pair_id");

            $c->req->params->{left_id} = $left_id;
            $c->req->params->{right_id} = $right_id;
            $c->req->params->{species} = $species;

            $c->controller('API')->pair_off_target_search($c);
            $c->log->debug("off target search response: ".Dumper($c->response));
            # FIXME: should get off target status from $c->response->body and present
            # message or error to user       
        }

        try{
            $c->log->debug("$action bookmark for crispr pair $crispr_pair_id");
            $c->model->bookmark_crispr_pair({
                username       => $c->user->name,
                crispr_pair_id => $crispr_pair_id,
                action         => $action,
            });
            $json_data->{message} = "$action bookmark for crispr pair $crispr_pair_id - done";
            #$c->stash->{json_data} = { message => "$action bookmark for crispr pair $crispr_pair_id - done" };
        }
        catch($e){
            $json_data->{error} = "Could not $action bookmark for crispr pair $crispr_pair_id - $e";
            #$c->stash->{json_data} = { error => "Could not $action bookmark for crispr pair $crispr_pair_id - $e" };
        }
    }
    else{
        # error, no user logged in
        $json_data->{error} = "Could not $action crispr pair bookmark - no logged in user";
        #$c->stash->{json_data} = { error => "Could not $action crispr pair bookmark - no logged in user" };
    }

    $c->stash->{json_data} = $json_data;
    $c->forward('View::JSON');

    return;
}

sub crispr_pair_report :Path('/crispr_pair') :Args(1){
    my ( $self, $c, $id ) = @_;

    my ( $left_id, $right_id ) = split '_', $id;

    # Try to find pair and stats in DB
    my $crispr_pair = $c->model->resultset('CrisprPair')->find( 
        { left_id => $left_id, right_id => $right_id  }
    );

    #get a hash of pair data
    my ( $pair, $species );
    if ( $crispr_pair ) {
        $pair = $crispr_pair->as_hash( { with_offs => 1, get_status => 1 } );
        $c->log->warn( "Found " . scalar @{ $pair->{off_targets} } );
        $species = $crispr_pair->get_species;
    }
    else {
        my $left_crispr = $c->model->resultset('Crispr')->find({ id => $left_id });
        my $right_crispr = $c->model->resultset('Crispr')->find({ id => $right_id });

        #gets a pair hash with spacer but no off target data
        $pair = $self->pair_finder->_check_valid_pair( $left_crispr, $right_crispr );
        $species = $left_crispr->get_species;
    }

    $c->stash( {
        pair          => $pair,
        species       => $species,
    } );

    if($c->user){
        $c->log->debug("Finding bookmarks for ".$c->user->name);
        $c->stash->{is_bookmarked} = any { $_->crispr_pair_id eq $id } $c->user->user_crispr_pairs;
    }
    return;
}

1;