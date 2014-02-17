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

sub crispr_pair_report :Path('/crispr_pair_report') :Args(1){
    my ( $self, $c, $id ) = @_;

    return;
}