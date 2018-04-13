package WGE::Controller::CrisprReports;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::CrisprReports::VERSION = '0.112';
}
## use critic

use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use IO::File;
use Bio::Perl qw( revcom_as_string );
use List::Util qw(sum);
use List::MoreUtils qw(any);
use WGE::Util::GenomeBrowser qw(crisprs_for_region);
use WGE::Util::OffTargetServer;


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

has pair_finder_with_schema => (
    is         => 'rw',
    isa        => 'WGE::Util::FindPairs',
);

has ots_server => (
    is => 'ro',
    isa => 'WGE::Util::OffTargetServer',
    lazy_build => 1,
);

sub _build_ots_server {
    return WGE::Util::OffTargetServer->new;
}

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

WGE::Controller::CrisprReports - Controller for Crispr report pages in WGE

=cut

sub novel_crispr_off_targets :Path('/novel_crispr_off_targets') :Args(0){
    my ( $self, $c ) = @_;

    my $pam = "NGG";

    my $seq = $c->req->param('seq');
    my $pam_right = $c->req->param('pam_right');

    my $crispr_seq;
    if($pam_right eq "true"){
        $crispr_seq = $seq.$pam;
    }
    elsif($pam_right eq "false"){
        $crispr_seq = revcom_as_string($pam).$seq;
    }
    else{
        $c->stash->{error_msg} = "pam_right must be true or false (not $pam_right)";
        return;
    }
    $c->stash->{crispr_seq} = $crispr_seq;

    $c->stash->{seq} = $seq;
    $c->stash->{pam_right} =  $pam_right;
    $c->stash->{species} = $c->req->param('species');

    my $fwd_seq = $pam_right eq "true" ? $crispr_seq : revcom_as_string( $crispr_seq );
    $c->stash->{crispr_fwd_seq} = $fwd_seq;

    my $data;
    try{
        $data = $self->ots_server->find_off_targets_by_seq({
            sequence => $seq,
            pam_right => $pam_right,
            species => $c->req->param('species'),
        });
    }
    catch{
        $c->stash->{error_msg} = $_ ;
    };

    if($data){
        my $crispr_hash->{off_target_summary} = $data->{off_target_summary};
        my @ot_ids = @{ $data->{off_targets} };
        my @ot_crisprs = $c->model->resultset('Crispr')->search({
            id => { -in => \@ot_ids }
        })->all;

        my @ot_hashes = map { $_->as_hash } @ot_crisprs;

        # For the standard crispr_report page the CrisprOffTargets as_hash method
        # revcoms the seq of the pam_left off-targets
        # As we are not using the CrisprOffTargets view we have to do the revcom here
        foreach my $ot_hash (@ot_hashes){
            if ( !$ot_hash->{pam_right} ) {
                $ot_hash->{seq} = revcom_as_string( $ot_hash->{seq} );
            }
        }

        $crispr_hash->{off_targets} = \@ot_hashes;
        $c->stash->{data} = $crispr_hash;
    }
    return;
}

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

    $c->log->info( "Finding pairs containing crispr ".$crispr->id );

    # Distance around original crispr to search for pairing
    # crisprs_for_region returns any crisprs with start in that region
    my $distance = 23 + $self->pair_finder->max_spacer;
    my $pair_search_start = $crispr->chr_start - $distance;
    my $pair_search_end = $crispr->chr_start + $distance;

    $c->log->info( "Finding nearby crisprs in region $pair_search_start to $pair_search_end" );
    my $species = $c->model('DB')->resultset('Species')->find({ numerical_id => $crispr->species_id });
    my $assembly_id = $species->species_default_assembly->assembly_id;
    my $nearby_crisprs = crisprs_for_region($c->model('DB'), {
        species_id        => $species->id,
        assembly_id       => $assembly_id,
        chromosome_number => $crispr->chr_name,
        start_coord       => $pair_search_start,
        end_coord         => $pair_search_end,
    });

    $c->log->info("Identifying pairs");
    my $pair_finder = $self->pair_finder_with_schema;
    unless($pair_finder){
        $pair_finder = WGE::Util::FindPairs->new({ schema => $c->model('DB')->schema });
        $self->pair_finder_with_schema($pair_finder);
    }
    my $crispr_pairs = $self->pair_finder_with_schema->find_pairs(
        [ $crispr ],
        [ $nearby_crisprs->all ],
        { get_db_data => 1, species_id => $species->numerical_id },
    );

    $c->log->info( "Stashing off target data" );

    my $crispr_hash = $crispr->as_hash( { with_offs => 1, always_pam_right => 1 } );
    my $fwd_seq = $crispr_hash->{pam_right} ? $crispr_hash->{seq} : revcom_as_string( $crispr_hash->{seq} );

    # If we have the off target summary but no list of off-targets there were too
    # many to store so calculate the total from the off-target summary
    if($crispr_hash->{off_target_summary} and !@{ $crispr_hash->{off_targets} }){
        my $summary = $crispr_hash->{off_target_summary};
        $c->log->debug("Off targets not stored. Caculating total offs from summary $summary.");
        my @values = ($summary =~ /:\s*(\d+)/g);
        my $total = sum @values;
        $crispr_hash->{off_target_total} = $total;
        $c->log->debug("Off-target total: $total");
    }

    $c->stash(
        crispr               => $crispr_hash,
        crispr_fwd_seq       => $fwd_seq,
        species              => $species->id,
        species_display_name => $species->display_name,
        crispr_pairs         => $crispr_pairs,
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

    unless ( $left_id && $right_id ) {
        $c->stash( error_msg => "Pair ID must be in the format left-crispr-id_right-crispr-id, e.g. 501037871_501037879" );
        return;
    }

    # Try to find pair and stats in DB
    my $crispr_pair = $c->model->resultset('CrisprPair')->find(
        { left_id => $left_id, right_id => $right_id  }
    );

    #get a hash of pair data
    my ( $pair, $species );
    if ( $crispr_pair ) {
        $pair = $crispr_pair->as_hash( { with_offs => 1, get_status => 1 } );
        $c->log->warn( "Found " . scalar @{ $pair->{off_targets} } );
        $species = $crispr_pair->species;
    }
    else {
        my $left_crispr = $c->model->resultset('Crispr')->find({ id => $left_id });
        my $right_crispr = $c->model->resultset('Crispr')->find({ id => $right_id });

        #gets a pair hash with spacer but no off target data
        $pair = $self->pair_finder->_check_valid_pair( $left_crispr, $right_crispr );
        $species = $left_crispr->species;
    }

    if ( $pair ) {
        $c->stash( {
            pair                 => $pair,
            species              => $species->id,
            species_display_name => $species->display_name,
        } );
    }
    else {
        $c->stash( error_msg => "Couldn't find CRISPR pair '$id'" );
    }

    if($c->user){
        $c->log->debug("Finding bookmarks for ".$c->user->name);
        $c->stash->{is_bookmarked} = any { $_->crispr_pair_id eq $id } $c->user->user_crispr_pairs;
    }
    return;
}

1;