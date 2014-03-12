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

sub gibson_design_gene_pick :Regex('gibson_design_gene_pick/(.*)'){
    my ( $self, $c ) = @_;

    my ($species) = @{ $c->req->captures };

    # Assert user role?
    $c->log->debug("Species: $species");

    # Allow species to be missing if session species already set
    if ($species) {
        unless($species eq "Human" or $species eq "Mouse"){
            $c->stash( error_msg => "Species $species not supported by WGE");
            return;
        }
        $c->session->{species} = $species;
    }
    else{
        unless($c->session->{species}) {
            $c->stash( error_msg => "No species provided");
        }
    }

    $c->log->debug("Session species: ".$c->session->{species});

    return unless $c->request->param('gene_pick');

    my $gene_id = $c->request->param('search_gene');
    unless ( $gene_id ) {
        $c->stash( error_msg => "Please enter a gene name" );
        return;
    }

    # if user entered a exon id
    if ( $gene_id =~ qr/^ENS[A-Z]*E\d+$/ ) {
        my $exon_id = $gene_id;
        my $create_design_util = WGE::Util::CreateDesign->new(
            catalyst => $c,
            model    => $c->model('DB'),
            species  => $c->session->{species},
        );

        my $exon_data;
        try{
            $exon_data = $create_design_util->c_exon_target_data( $exon_id );
        }
        catch {
            $c->stash( error_msg =>
                    "Unable to find gene information for exon $exon_id, make sure it is a valid ensembl exon id"
            );
            return;
        }

        $c->stash(
            gene_id         => $exon_data->{gene_id},
            ensembl_gene_id => $exon_data->{ensembl_gene_id},
            gibson_type     => 'deletion',
            five_prime_exon => $exon_id,
        );
        $c->go( 'create_gibson_design' );
    }
    else {
        # generate and display data for exon pick table
        $c->forward( 'generate_exon_pick_data' );
        return if $c->stash->{error_msg};

        $c->go( 'gibson_design_exon_pick' );
    }

    return;
}

sub gibson_design_exon_pick :Path('/gibson_design_exon_pick') :Args(0){
    my ( $self, $c ) = @_;

    # Assert user role?
    if ( $c->request->params->{pick_exons} ) {

        my $exon_picks = $c->request->params->{exon_pick};

        unless ( $exon_picks ) {
            $c->stash( error_msg => "No exons selected" );
            $c->forward( 'generate_exon_pick_data' );
            return;
        }

        my %stash_hash = (
            gene_id         => $c->request->param('gene_id'),
            ensembl_gene_id => $c->request->param('ensembl_gene_id'),
            gibson_type     => 'deletion',
        );

        # if multiple exons, its an array_ref
        if (ref($exon_picks) eq 'ARRAY') {
            $stash_hash{five_prime_exon}  = $exon_picks->[0];
            $stash_hash{three_prime_exon} = $exon_picks->[-1];
        }
        # if its not an array_ref, it is a string with a single exon
        else {
            $stash_hash{five_prime_exon} = $exon_picks;
        }

        $c->stash( %stash_hash );

        $c->go( 'create_gibson_design' );

    }

    return;
}

sub generate_exon_pick_data : Private {
    my ( $self, $c ) = @_;

    $c->log->debug("Pick exon targets for gene: " . $c->request->param('search_gene') );
    try {
        my $create_design_util = WGE::Util::CreateDesign->new(
            catalyst => $c,
            model    => $c->model('DB'),
            species  => $c->session->{species},
        );
        my ( $gene_data, $exon_data ) = $create_design_util->exons_for_gene(
            $c->request->param('search_gene'),
            $c->request->param('show_exons'),
        );

        $c->stash(
            exons       => $exon_data,
            gene        => $gene_data,
            search_gene => $c->request->param('search_gene'),
            assembly    => $create_design_util->assembly_id,
            show_exons  => $c->request->param('show_exons'),
        );
    }
    catch($e){
        my $message = "Problem finding gene: $e";
        $c->log->error($message);
        $c->stash( error_msg => $message );
    };

    return;
}

sub create_gibson_design : Path( '/create_gibson_design' ) : Args {
    my ( $self, $c, $is_redo ) = @_;

    my $create_design_util = WGE::Util::CreateDesign->new(
        catalyst => $c,
        model    => $c->model('DB'),
        species  => $c->session->{species},
    );

    my $primer3_conf = $create_design_util->c_primer3_default_config;
    $c->stash( default_p3_conf => $primer3_conf );

    if ( $is_redo && $is_redo eq 'redo' ) {
        # if we have redo flag all the stash variables have been setup correctly
        return;
    }
    elsif ( exists $c->request->params->{create_design} ) {
        $self->_create_gibson_design( $c, $create_design_util, 'create_exon_target_gibson_design' );
    }

    return;
}

sub create_custom_target_gibson_design : Path( '/create_custom_target_gibson_design' ) : Args {
    my ( $self, $c, $is_redo ) = @_;

    my $create_design_util = WGE::Util::CreateDesign->new(
        catalyst => $c,
        model    => $c->model('DB'),
        species  => $c->session->{species},
    );
    $c->stash( default_p3_conf => $create_design_util->c_primer3_default_config );

    if ( $is_redo && $is_redo eq 'redo' ) {
        # if we have redo flag all the stash variables have been setup correctly
        return;
    }
    elsif ( exists $c->request->params->{create_design} ) {
        $self->_create_gibson_design( $c, $create_design_util, 'create_custom_target_gibson_design' );
    }
    elsif ( exists $c->request->params->{target_from_exons} ) {
        my $target_data = $create_design_util->c_target_params_from_exons;
        $c->stash(
            gibson_type => 'deletion',
            %{ $target_data },
        );
    }

    return;
}

sub _create_gibson_design {
    my ( $self, $c, $create_design_util, $cmd ) = @_;

    $c->log->info('Creating new gibson design');

    my ($design_attempt, $job_id);
    $c->stash( $c->request->params );
    try {
        ( $design_attempt, $job_id ) = $create_design_util->$cmd;
    }
    catch ( WGE::Exception::Validation $err ) {
        my $errors = $create_design_util->c_format_validation_errors( $err );
        $c->log->warn( "User create gibson design error: $errors " );
        $c->stash( error_msg => $errors );
        return;
    }
    catch ($err) {
        $c->log->error( "Error submitting gibson design job: $err" );
        $c->stash( error_msg => "Error submitting Design Creation job: $err" );
        return;
    }

    unless ( $job_id ) {
        $c->log->warn( 'Unable to submit Design Creation job' );
        $c->stash( error_msg => "Unable to submit Design Creation job" );
        return;
    }

    $c->res->redirect( $c->uri_for('/design_attempt', $design_attempt->id , 'pending') );

    return;
}

sub design_attempt : PathPart('design_attempt') Chained('/') CaptureArgs(1) {
    my ( $self, $c, $design_attempt_id ) = @_;

    # FIXME assert user role edit

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

    my $da = $c->stash->{da};
    my $da_hash = $da->as_hash( { json_as_hash => 1 } );

    $c->stash(
        da     => $da->as_hash( { pretty_print_json => 1 } ),
        fail   => $da_hash->{fail},
        params => $da_hash->{design_parameters},
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

sub redo_design_attempt : PathPart('redo') Chained('design_attempt') : Args(0) {
    my ( $self, $c ) = @_;

    my $da = $c->stash->{da};
    my $da_data = $da->as_hash( { json_as_hash => 1 } );
    my $species = $da_data->{design_parameters}{species};
    $c->session->{species} = $species;

    my $create_design_util = WGE::Util::CreateDesign->new(
        catalyst => $c,
        model    => $c->model('DB'),
        species  => $species,
    );

    my $gibson_target_type;
    try {
        # this will stash all the needed design parameters
        $gibson_target_type = $create_design_util->redo_design_attempt( $da );
    }
    catch ( $err ) {
        $c->stash(error_msg => "Error processing parameters from design attempt "
                . $da->id . ":\n" . $err
                . "Unable to redo design" );
        return $c->go('design_attempts');
    }

    if ( $gibson_target_type eq 'exon' ) {
        return $c->go( 'create_gibson_design', [ 'redo' ] );
    }
    elsif ( $gibson_target_type eq 'location' ) {
        return $c->go( 'create_custom_target_gibson_design' , [ 'redo' ] );
    }
    else {
        $c->stash( error_msg => "Unknown gibson target type $gibson_target_type"  );
        return $c->go('design_attempts');
    }

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
        'flank_size'    => $c->request->params->{'flank_size'},
    );

    return;
}

1;
