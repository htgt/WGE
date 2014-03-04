package WGE::Controller::CrisprReports;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use IO::File;
use Bio::Perl qw( revcom_as_string );

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

    return;
}

1;