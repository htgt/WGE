package WGE::Controller::Gibson;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use IO::File;
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

    my $design_data = $self->_fetch_design_data($c);

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
        $c->detach('view_design', [ design_id => $design_id ] );
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

    my $design_data = $self->_fetch_design_data($c);

    my $filename = "WGE_design_".$design_data->{id}.".csv";

    # FIXME: print design data as csv...
    $c->response->status( 200 );
    $c->response->content_type( 'text/csv' );
    $c->response->header( 'Content-Disposition' => "attachment; filename=$filename" );
    $c->response->body( Dumper($design_data) );

    return;    
}

sub genoverse_browse_view :Path( '/genoverse_browse') : Args(0){
    my ($self, $c) = @_;

    my @required = qw(genome chromosome browse_start browse_end);
    my @missing_params = grep { not defined $c->request->params->{$_ } } @required;

    if (@missing_params){
        # get info for initial display from design oligos...
        my $design_data = $self->_fetch_design_data($c);
    
        my ($start, $end, $chromosome, $genome);
        foreach my $oligo (@{ $design_data->{oligos} || [] }){
            $chromosome ||= $oligo->{locus}->{chr_name};
            $genome   ||= $oligo->{locus}->{assembly};
            my $oligo_start = $oligo->{locus}->{chr_start};
            my $oligo_end = $oligo->{locus}->{chr_end};

            if ($oligo_start > $oligo_end){
                die "Was not expecting oligo start to be after oligo end";
            }

            if (not defined $start or $start > $oligo_start){
                $start = $oligo_start;
            }

            if (not defined $end or $end < $oligo_end){
                $end = $oligo_end;
            }
        }

        $c->stash(
            'genome'        => $genome,
            'chromosome'    => $chromosome,
            'browse_start'  => $start,
            'browse_end'    => $end,
            'view_single'   => $c->request->params->{'view_single'},
            'view_paired'   => $c->request->params->{'view_paired'},
            'design_id'     => $design_data->{id},
            'genes'         => $design_data->{assigned_genes},
        );
    }
    else{

        # genome coords have already been provided, e.g. when
        # we adjust the view_single/view_paired params
        $c->stash(
            'genome'        => $c->request->params->{'genome'},
            'chromosome'    => $c->request->params->{'chromosome'},
            'browse_start'  => $c->request->params->{'browse_start'},
            'browse_end'    => $c->request->params->{'browse_end'},
            'view_single'   => $c->request->params->{'view_single'},
            'view_paired'   => $c->request->params->{'view_paired'},
            'design_id'     => $c->request->params->{'design_id'},
            'genes'         => $c->request->params->{'genes'}
        );
    }
    return;
}

sub _fetch_design_data{
    my ($self, $c) = @_;

    my $design_id  = $c->request->param('design_id');

    my $design;
    try {
        $design = $c->model->c_retrieve_design( { id => $design_id } );
    }
    catch( LIMS2::Exception::Validation $e ) {
        $c->stash( error_msg => "Please provide a valid design id" );
        return $c->go('index');
    } catch( LIMS2::Exception::NotFound $e ) {
        $c->stash( error_msg => "Design $design_id not found" );
        return $c->go('index');
    }

    my $design_data = $design->as_hash;
    $design_data->{assigned_genes} = join q{, }, @{ $design_data->{assigned_genes} || [] };

    $c->log->debug( "Design: " .Dumper($design_data) );

    return $design_data;    
}