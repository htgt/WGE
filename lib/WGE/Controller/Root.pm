package WGE::Controller::Root;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use Try::Tiny;

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

sub gibson_design_gene_pick :Path('/gibson') :Args(0){
    my ( $self, $c ) = @_;

    # Assert user role?

    return;
}

sub gibson_design_exon_pick :Path('/gibson_design_exon_pick') :Args(0){
    my ( $self, $c ) = @_;

    # Assert user role?

    my $gene_name = $c->request->param('gene');

    unless ( $gene_name ) {
        # FIXME: make form display this
        $c->stash( error_msg => "Please enter a gene name" );
        
        return $c->go('gibson_design_gene_pick');
    }

    $c->log->debug("Pick exon targets for gene $gene_name");
    try {
=head
        my $create_design_util = LIMS2::Model::Util::CreateDesign->new(
            catalyst => $c,
            model    => $c->model('Golgi'),
        );
        my ( $gene_data, $exon_data )= $create_design_util->exons_for_gene(
            $c->request->param('gene'),
            $c->request->param('show_exons'),
        );
=cut
        # Implement design creation using WebApp common module
        my $exon_data = {};
        my $gene_data = {};
        my $assembly = "fixme";

        $c->stash(
            exons    => $exon_data,
            gene     => $gene_data,
            assembly => $assembly,
        );
    }
    catch{
        $c->stash( error_msg => "Problem finding gene: $_" );
        $c->go('gibson_design_gene_pick');
    };  

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
