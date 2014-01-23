package WGE::Controller::Root;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use Try::Tiny;
use WGE::Util::CreateDesign;

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

sub gibson_design_gene_pick :Path('/gibson_design_gene_pick') :Args(0){
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

        my $create_design_util = WGE::Util::CreateDesign->new(
            catalyst => $c,
            model    => $c->model('DB'),
        );
        my ( $gene_data, $exon_data )= $create_design_util->exons_for_gene(
            $c->request->param('gene'),
            $c->request->param('show_exons'),
        );

        $c->stash(
            exons    => $exon_data,
            gene     => $gene_data,
            assembly => $create_design_util->assembly_id,
        );
    }
    catch{
        my $message = "Problem finding gene: $_";
        $c->log->error($message);
        $c->stash( error_msg => $message );
        $c->go('gibson_design_gene_pick');
    };  

    return;
}

sub create_gibson_design : Path( '/create_gibson_design' ) : Args(0) {
    my ( $self, $c ) = @_;

    # FIXME assert user role edit

    if ( exists $c->request->params->{create_design} ) {
        $c->log->info('Creating new design');

        my $create_design_util = WGE::Util::CreateDesign->new(
            catalyst => $c,
            model    => $c->model('DB'),
        );

        my $design_attempt;
        try {
            $design_attempt = $create_design_util->create_gibson_design();
        }
        catch {
            $c->log->error($_);
            $c->stash( error_msg => "Error submitting Design Creation job: $_" );
            $c->res->redirect( 'gibson_design_gene_pick' );
            return;
        };

        $c->res->redirect( $c->uri_for('/user/design_attempt', $design_attempt->id , 'pending') );
    }
    elsif ( exists $c->request->params->{exon_pick} ) {
        my $gene_id = $c->request->param('gene_id');
        my $exon_id = $c->request->param('exon_id');
        my $ensembl_gene_id = $c->request->param('ensembl_gene_id');
        $c->stash(
            exon_id         => $exon_id,
            gene_id         => $gene_id,
            ensembl_gene_id => $ensembl_gene_id,
        );
    }

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
