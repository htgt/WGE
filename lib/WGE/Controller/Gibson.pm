package WGE::Controller::Gibson;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use IO::File;
use WGE::Util::CreateDesign;
use WGE::Util::GenomeBrowser qw(fetch_design_data get_region_from_params);
use WGE::Util::ExportCSV qw(write_design_data_csv);

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

        my ($design_attempt, $job_id);
        try {
            ( $design_attempt, $job_id ) = $create_design_util->create_exon_target_gibson_design();
        }
        catch($e) {
            $c->log->error($e);
            $c->flash( error_msg => "Error submitting Design Creation job: $e" );
            $c->res->redirect( 'gibson_design_gene_pick' );
            return;
        };

        unless ( $job_id ) {
            $c->flash( error_msg => "Unable to submit Design Creation job" );
            $c->res->redirect( 'gibson_design_gene_pick' );
            return;
        }

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

sub create_custom_target_gibson_design : Path( '/create_custom_target_gibson_design' ) : Args(0) {
    my ( $self, $c ) = @_;

    # FIXME assert user role edit

    my $create_design_util = WGE::Util::CreateDesign->new(
        catalyst => $c,
        model    => $c->model('DB'),
        species  => $c->session->{species},
    );

    if ( exists $c->request->params->{create_design} ) {
        $c->log->info('Creating new design');


        my ($design_attempt, $job_id);
        try {
            ( $design_attempt, $job_id ) = $create_design_util->create_custom_target_gibson_design();
        }
        catch ($e) {
            $c->log->error($e);
            $c->flash( error_msg => "Error submitting Design Creation job: $e" );
            $c->res->redirect( 'gibson_design_gene_pick' );
            return;
        }

        unless ( $job_id ) {
            $c->flash( error_msg => "Unable to submit Design Creation job" );
            $c->res->redirect( 'gibson_design_gene_pick' );
            return;
        }

        $c->res->redirect( $c->uri_for('/design_attempt', $design_attempt->id , 'pending') );
    }
    elsif ( exists $c->request->params->{target_from_exons} ) {
        my $target_data = $create_design_util->target_params_from_exons;
        $c->stash(
            target => $target_data,
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

my @DISPLAY_DESIGN = (
    [ 'Design id'               => 'id' ],
    [ 'Type'                    => 'type' ],
    [ 'Assigned to gene(s)'     => 'assigned_genes' ],
    [ 'Created by'              => 'created_by' ],
    [ 'Created at'              => 'created_at' ]
);

sub view_design :Path( '/view_gibson_design' ) : Args(0) {
    my ( $self, $c ) = @_;

    #$c->assert_user_roles( 'read' );

    my $design_data = fetch_design_data($c->model, $c->request->params);

    my $species_id = $design_data->{species};

    my $download_link = $c->uri_for('/download_design',{ design_id => $design_data->{id}});

    $c->stash(
        design         => $design_data,
        display_design => \@DISPLAY_DESIGN,
        species        => $species_id,
        download_link  => $download_link,
    );

    return;    
}

sub view_gibson_designs :Path( '/view_gibson_designs' ) : Args(0) {
    my ($self, $c) = @_;

    # assert user roles

    my $action = $c->request->param('action');

    return unless $action;

    if ($action eq "View Design"){
        my $design_id = $c->request->param('design_id');
        
        unless ($design_id){
            $c->stash( error_msg => "Please provide a design id");
            return;
        }

        unless ($c->model->resultset('Design')->find({ id => $design_id })){
            $c->stash( error_msg => "Design id $design_id not found");
            return;            
        }
        
        $c->stash->{template} = 'view_design.tt';

        my $view_uri = $c->uri_for('view_gibson_design', {design_id => $design_id});
        $c->response->redirect( $view_uri );
        $c->detach;
    }
    elsif ($action eq "View Design Attempt"){
        my $attempt_id = $c->request->param('design_attempt_id');
        
        unless ($attempt_id){
            $c->stash( error_msg => "Please provide a design attempt id");
            return;
        }

        unless ($c->model->resultset('DesignAttempt')->find({ id => $attempt_id })){
            $c->stash( error_msg => "Design Attempt id $attempt_id not found");
            return;            
        }

        $c->stash->{template} = 'view_design_attempt.tt';
        my $view_uri = $c->uri_for_action('view_design_attempt', [ $attempt_id ]);
        $c->log->debug( "redirecting to: $view_uri" );
        $c->response->redirect( $view_uri );
        $c->detach;
    }

    return;
}

sub download_design :Path( '/download_design' ) : Args(0) {
    my ( $self, $c ) = @_;

    #$c->assert_user_roles( 'read' );

    my $design_data = fetch_design_data($c->model, $c->request->params);

    my $filename = "WGE_design_".$design_data->{id}.".csv";

    my $content = write_design_data_csv($design_data, \@DISPLAY_DESIGN);

    $c->response->status( 200 );
    $c->response->content_type( 'text/csv' );
    $c->response->header( 'Content-Disposition' => "attachment; filename=$filename" );
    $c->response->body( $content );

    return;    
}

sub genoverse_browse_view :Path( '/genoverse_browse') : Args(0){
    my ($self, $c) = @_;

    my $region;
    try{
        $region = get_region_from_params($c->model, $c->request->params);
    }
    catch ($e){
        $c->stash( error_msg => "Could not display genome browser: $e" );
        return;
    }

    $c->log->debug('Displaying region: '.Dumper($region));

    $c->stash(
        'genome'        => $region->{'genome'},
        'chromosome'    => $region->{'chromosome'},
        'browse_start'  => $region->{'browse_start'},
        'browse_end'    => $region->{'browse_end'},
        'genes'         => $region->{'genes'},
        'design_id'     => $c->request->params->{'design_id'},           
        'view_single'   => $c->request->params->{'view_single'},
        'view_paired'   => $c->request->params->{'view_paired'},
        'crispr_filter' => $c->request->params->{'crispr_filter'},
    );

    return;
}

1;
