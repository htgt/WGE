package WGE::Controller::Gibson;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use WGE::Util::CreateDesign;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

WGE::Controller::Gibson - Controller for Gibson related pages in WGE

=cut

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
        $c->stash( error_msg => "Please enter a gene name" );
        
        return $c->go('gibson_design_gene_pick');
    }

    $c->log->debug("Pick exon targets for gene $gene_name");
    try {

        my $create_design_util = WGE::Util::CreateDesign->new(
            catalyst => $c,
            model    => $c->model('DB'),
            species  => $c->request->param('species'),
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
        
        # Store this in the session because we need to know
        # when we create the design
        $c->session->{species} = $c->request->param('species');
    }
    catch($e){
        my $message = "Problem finding gene: $e";
        $c->log->error($message);
        $c->flash( error_msg => $message );
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
            species  => $c->session->{species},
        );

        my $design_attempt;
        try {
            $design_attempt = $create_design_util->create_gibson_design();
        }
        catch($e) {
            $c->log->error($e);
            $c->flash( error_msg => "Error submitting Design Creation job: $e" );
            $c->res->redirect( 'gibson_design_gene_pick' );
            return;
        };

        $c->res->redirect( $c->uri_for('/design_attempt', $design_attempt->id , 'pending') );
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

sub design_attempt : PathPart('design_attempt') Chained('/') CaptureArgs(1) {
    my ( $self, $c, $design_attempt_id ) = @_;

    #$c->assert_user_roles( 'read' );

    my $design_attempt;
    try {
        $design_attempt = $c->model
            ->c_retrieve_design_attempt( { id => $design_attempt_id } );
    }
    catch( LIMS2::Exception::Validation $e ) {
        $c->stash( error_msg => "Please enter a valid design attempt id" );
        return $c->go('design_attempts');
    }
    catch( LIMS2::Exception::NotFound $e ) {
        $c->stash( error_msg => "Design Attempt $design_attempt_id not found" );
        return $c->go('design_attempts');
    }

    $c->log->debug( "Retrived design_attempt: $design_attempt_id" );

    $c->stash(
        da      => $design_attempt,
        species => $design_attempt->species_id,
    );

    return;
}

sub view_design_attempt : PathPart('view') Chained('design_attempt') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(
        da => $c->stash->{da}->as_hash( { pretty_print_json => 1 } ),
    );
    return;
}

sub gibson_design_attempts :Path( '/gibson_design_attempts' ) : Args(0) {
    my ( $self, $c ) = @_;

    #TODO make this a extjs grid to enable filtering, sorting etc 

    my @design_attempts = $c->model->resultset('DesignAttempt')->search(
        {
        },
        {
            order_by => { '-desc' => 'created_at' },
            rows => 50,
        }
    );

    $c->stash (
        das => [ map { $_->as_hash( { json_as_hash => 1 } ) } @design_attempts ],
    );
    return;
}

sub pending_design_attempt : PathPart('pending') Chained('design_attempt') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(
        id      => $c->stash->{da}->id,
        status  => $c->stash->{da}->status,
        gene_id => $c->stash->{da}->gene_id,
    );
    return;
}