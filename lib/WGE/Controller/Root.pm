package WGE::Controller::Root;

use Moose;
use namespace::autoclean;
use Data::Dumper;
use Try::Tiny;
use Bio::Perl qw( revcom_as_string );

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

WGE::Controller::Root - Root Controller for WGE

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    return;
}

sub numbers :Path('/numbers') :Args(0){
    my ( $self, $c ) = @_;
    
    my $model = $c->model('DB');
    
    $c->stash->{num_genes}   = $model->resultset('Gene')->count, 
    $c->stash->{num_exons}   = $model->resultset('Exon')->count,
    $c->stash->{num_crisprs} = $model->resultset('Crispr')->count,
    $c->stash->{num_pairs}   = $model->resultset('CrisprPair')->count,    
    
    return;	
}

sub about :Path('/about') :Args(0){
    my ( $self, $c ) = @_;
    
    return;	
}

sub contact :Path('/contact') :Args(0){
    my ( $self, $c ) = @_;
    
    return;	
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}


=head2 default

Crispr data page

=cut

sub crispr_data :Path('/crispr') :Args(1){
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

# sub paired_crispr_data :Path('/crispr_pair') :Args(1) {
#     my ( $self, $c, $pair_id ) = @_;

#     my ( $l_crispr_id, $r_crispr_id ) = split '_', $pair_id;

#     my $pair;
#     #do in a try in case an sql error/dbi is raised
#     try {
#         $pair = $c->model('DB')->resultset('CrisprPair')->find( 
#             { left_id => $l_crispr_id, right_id => $r_crispr_id } 
#         );
#     }
#     catch {
#         $c->log->warn( $_ );
#     };

#     $c->stash(
#         pair => $pair,
        
#     );
# }

# sub paired_crispr_data :Path('/crispr_pair') :Args(2){
#     my ( $self, $c, $l_crispr_id, $r_crispr_id ) = @_;

#     my $pair = $c->model('DB')->resultset("CrisprPair")->find({left_id=>$l_crispr_id, right_id=>$r_crispr_id});

#     my $l_crispr = $c->model('DB')->resultset('Crispr')->find({ id => "$l_crispr_id" });
#     my $r_crispr = $c->model('DB')->resultset('Crispr')->find({ id => "$r_crispr_id" });
#     $c->stash->{l_crispr_seq} = $l_crispr->seq;
#     $c->stash->{r_crispr_seq} = $r_crispr->seq;
#     $c->stash->{off_target_count} = scalar( @{ $pair->off_targets } );

#     $c->stash->{spacer} = $r_crispr->chr_start - ($l_crispr->chr_start+22) - 1;
    
#     # my $crispr_seq = $crispr->seq;

# # my $right_crispr = $crispr->right_crispr;
# # my $left_crispr = $crispr->left_crispr;


#     my @off_targets = $pair->off_targets;

# use Smart::Comments;
# ## @off_targets 


#     my @table;
#     foreach my $crispr (@off_targets) {

#         print $crispr->{left_crispr}->seq;


#         my $species;
#         if ($crispr->{left_crispr}->species_id == 1 && $crispr->{right_crispr}->species_id == 1) {
#             $species = "Homo_sapiens";
#         }
#         elsif ($crispr->{left_crispr}->species_id == 2 && $crispr->{right_crispr}->species_id == 2) {
#             $species = "Mus_Musculus";
#         }

#         my $l_start = $crispr->{left_crispr}->chr_start;
#         my $l_end = $crispr->{left_crispr}->chr_start + 22;
#         my $l_location = $crispr->{left_crispr}->chr_name . ":$l_start-$l_end";

#         my $spacer = $crispr->{right_crispr}->chr_start - ($crispr->{left_crispr}->chr_start+22) - 1;

#         my $r_start = $crispr->{right_crispr}->chr_start;
#         my $r_end = $crispr->{right_crispr}->chr_start + 22;
#         my $r_location = $crispr->{right_crispr}->chr_name . ":$r_start-$r_end";

#         push (@table, {
#             l_location  => $l_location,
#             r_location  => $r_location,
#             spacer      => $spacer,
#             l_seq       => $crispr->{left_crispr}->seq,
#             r_seq       => $crispr->{right_crispr}->seq,
#             species     => $species,
#             l_pam_right => $crispr->{left_crispr}->pam_right,
#             r_pam_right => $crispr->{right_crispr}->pam_right,
#         });
        
#     }

#     ### @table

#     $c->stash->{off_targets} = \@table;

#     return; 
# }





=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Anna Farne

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
