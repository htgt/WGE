package WGE::Controller::CrisprReports;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use IO::File;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

WGE::Controller::CrisprReports - Controller for Crispr report pages in WGE

=cut

sub crispr_report :Path('/crispr_report') :Args(1){
    my ( $self, $c, $id ) = @_;

    my $display_items = [
        ['Crispr ID'  => 'id' ],
        ['Species'    => 'species' ],
        ['Chromosome' => 'chr_name' ],
        ['Start'      => 'chr_start'],
        ['End'        => 'chr_end' ],
        ['Sequence'   => 'seq'],
        ['PAM right'  => 'pam_right'],
    ]; 

    $id =~ s/^WGE-//;

    my $crispr = $c->model->resultset('Crispr')->find({ id => $id })->as_hash;

    # Change species numerical id to name
    my $species = $c->model->resultset('Species')->find({ numerical_id => $crispr->{species} });
    $crispr->{species} = $species->id;

    # Report PAM right as true/false not 1/0
    $crispr->{pam_right} ? $crispr->{pam_right} = 'true' : $crispr->{pam_right} = 'false';

    $c->stash({ 
    	crispr        => $crispr,
    	display_items => $display_items,
    });

    return;
}

sub crispr_pair_report :Path('/crispr_pair') :Args(1){
    my ( $self, $c, $id ) = @_;

    my $display_items = [
        ['Species'    => 'species' ],
        ['Chromosome' => 'chr_name' ],
        ['Start'      => 'chr_start'],
        ['End'        => 'chr_end' ],
        ['Sequence'   => 'seq'],
        ['PAM right'  => 'pam_right'],
    ];

    # I am allowing ID to be in different formats:
    # WGE_1234:5678 (used in genoverse view) or 1234_5678
    # should stick to the one used as id in crispr_pairs i.e. 1234_5678
    $id =~ s/^WGE-//;
    my ($left_id, $right_id) = split qr/[\:_]/, $id;

    my ($left_crispr, $right_crispr, $spacer);

    # Try to find pair and stats in DB
    my $crispr_pair = $c->model->resultset('CrisprPair')->find({ left_id => $left_id, right_id => $right_id });

    if ($crispr_pair){
        $left_crispr = $crispr_pair->left->as_hash;
        $right_crispr = $crispr_pair->right->as_hash;
        $spacer = $crispr_pair->spacer;
    }
    else{
        $left_crispr = $c->model->resultset('Crispr')->find({ id => $left_id })->as_hash;
        $right_crispr = $c->model->resultset('Crispr')->find({ id => $right_id })->as_hash;
        $spacer = $c->req->param('spacer');
    }

    foreach my $crispr ($left_crispr, $right_crispr){
        my $species = $c->model->resultset('Species')->find({ numerical_id => $crispr->{species} });
        $crispr->{species} = $species->id;

        # Report PAM right as true/false not 1/0
        $crispr->{pam_right} ? $crispr->{pam_right} = 'true' : $crispr->{pam_right} = 'false';
    }

    $c->stash({
        left_crispr => $left_crispr,
        right_crispr => $right_crispr,
        display_items => $display_items,
        crispr_pair => $crispr_pair,
        spacer => $spacer,
    });

    return;
}