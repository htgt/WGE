package WGE::Controller::API;

use Moose;
use WGE::Util::GenomeBrowser qw(
    gibson_designs_for_region 
    design_oligos_to_gff 
    crisprs_for_region 
    crisprs_to_gff
    crispr_pairs_for_region
    crispr_pairs_to_gff
    );
use namespace::autoclean;
use Data::Dumper;

use WGE::Util::FindPairs;

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


=head1 NAME

WGE::Controller::API - API Controller for WGE

=head1 DESCRIPTION

Contains methods which provide data to javascript requests
and do not require user authentication.

Authenticated requests should use the REST API

=cut

#so we can species in js
sub get_all_species :Local('get_all_species') {
    my ( $self, $c ) = @_;

    my @species = $c->model('DB')->resultset('Species')->all;

    $c->stash->{json_data} = { 
        map { $_->numerical_id => $_->id } @species
    };
    $c->forward('View::JSON');
}

sub gene_search :Local('gene_search') {
    my ($self, $c) = @_;
    my $params = $c->req->params;
    
    check_params_exist( $c, $params, [ 'name', 'species' ] );

    $c->log->debug('Searching for marker symbol ' . $params->{name} . ' for ' . $params->{species});



    my @genes = $c->model('DB')->resultset('Gene')->search( 
        {
            #'marker_symbol' => { ilike => '%'.param("name").'%' },
            'UPPER(marker_symbol)' => { like => '%'.uc( $params->{name} ).'%' },
            'species_id'           => $params->{species},
        }
    );

    #return a list of hashrefs with the matching gene data
    $c->stash->{json_data}  = [ sort map { $_->marker_symbol } @genes ];
    $c->forward('View::JSON');
}

sub exon_search :Local('exon_search') {
    my ($self, $c) = @_;
    my $params = $c->req->params;
    
    check_params_exist( $c, $params, [ 'marker_symbol', 'species' ] );
    
    $c->log->debug('Finding exons for gene ' . $params->{marker_symbol});

    my $gene = $c->model('DB')->resultset('Gene')->find(
        { marker_symbol => $params->{marker_symbol}, species_id => $params->{species} },
        { prefetch => 'exons', order_by => { -asc => 'ensembl_exon_id' } }
    );

    _send_error( $c, "No exons found", 400 ) unless $gene;

    my @exons = map { 
            {
                exon_id => $_->ensembl_exon_id, 
                rank    => $_->rank,
                len     => $_->chr_end - $_->chr_start,
            } 
        } sort { $a->rank <=> $b->rank } $gene->exons;

    #return a list of hashrefs with the matching exon ids and ranks
    $c->stash->{json_data} = { transcript => $gene->canonical_transcript, exons => \@exons };
    $c->forward('View::JSON');
}

sub crispr_search :Local('crispr_search') {
    my ($self, $c) = @_;
    my $params = $c->req->params;
    
    check_params_exist( $c, $params, [ 'exon_id[]' ]);
    
    $c->stash->{json_data} = _get_exon_attribute( $c, "crisprs", $params->{ 'exon_id[]' } );
    $c->forward('View::JSON');
}

sub pair_search :Local('pair_search') {
    my ($self, $c) = @_;
    my $params = $c->req->params;
    
    check_params_exist( $c, $params, [ 'exon_id[]' ]);
    
    $c->stash->{json_data} = _get_exon_attribute( $c, "pairs", $params->{ 'exon_id[]' } );
    $c->forward('View::JSON');
}

sub pair_off_target_search :Local('pair_off_target_search') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    check_params_exist( $c, $params, [ qw( species left_id right_id ) ] );

    #for now we will trust that what we got was a valid pair.
    #we will need to verify or someone can send any old crap.
    #we need to get the spacer AGAIN here, ugh
    
    # also need to make extra sure someone can't put '24576 || rm -rf *' or something

    my $species_id = $c->model('DB')->resultset('Species')->find(
        { id       => $params->{species} }
    )->numerical_id;


    my $pair = $c->model('DB')->resultset('CrisprPair')->find( 
        { 
            left_id    => $params->{left_id}, 
            right_id   => $params->{right_id},
            species_id => $species_id,
        }
    );

    #if the pair doesn't exist create it, note that this is subject to a race condition,
    #we should add locks to the table (david said it's part of select syntax)
    unless ( $pair ) {
        #find the crispr entries so we can check they are a valid pair
        my @crisprs = $c->model('DB')->resultset('Crispr')->search( 
            {  
                id         => { -IN => [ $params->{left_id}, $params->{right_id} ] },
                species_id => $species_id
            }
        );

        #identify if the chosen crisprs are valid by
        #checking the list of crisprs against itself for pairs
        my $pairs = $self->pair_finder->find_pairs( \@crisprs, \@crisprs );

        die "Found more than one pair??" if @{ $pairs } > 1;

        $pair = $c->model('DB')->resultset('CrisprPair')->create( 
            {
                left_id    => $pairs->[0]{left_crispr}{id},
                right_id   => $pairs->[0]{right_crispr}{id},
                spacer     => $pairs->[0]{spacer},
                species_id => $species_id,

            },
            { key => 'primary' }
        );

    }

    $c->stash->{json_data} = { 'success' => 1 };
    $c->forward('View::JSON');
}

# sub pair_off_target_search :Local('pair_off_target_search') {
# 	my ($self, $c) = @_;
# 	my $params = $c->req->params;
	
# 	check_params_exist( $c, $params, [ 'pair_id[]' ]);
	
# 	my @data;
# 	my $pair_id = $params->{ 'pair_id[]'};
# 	my @pair_ids = ( ref $pair_id eq 'ARRAY' ) ? @{ $pair_id } : ( $pair_id );

# 	foreach my $id ( @pair_ids ){
# 		push @data, "Processing pair $id";
# 	}
#   $c->stash->{json_data} = \@data;
#   $c->forward('View::JSON');
# }	


sub design_attempt_status :Chained('/') PathPart('design_attempt_status') Args(1) {
    my ( $self, $c, $da_id ) = @_;
 
    # require authenticated user for this request?
    
    $c->log->debug("Getting status for design attempt $da_id");

    my $da = $c->model->c_retrieve_design_attempt( { id => $da_id } );
    my $status = $da->status;
    my $design_links;
    if ( $status eq 'success' ) {
        my @design_ids = split( ' ', $da->design_ids );
        for my $design_id ( @design_ids ) {
            my $link = $c->uri_for('/view_gibson_design', { design_id => $design_id } )->as_string;
            $design_links .= '<a href="' . $link . '">'. $design_id .'</a><br>';
        }
    }

    $c->stash->{json_data} = { status => $status, designs => $design_links };
    $c->forward('View::JSON');
}

sub designs_in_region :Local('designs_in_region') Args(0){
    my ($self, $c) = @_;

    my $schema = $c->model->schema;
    my $params = {
        assembly_id          => $c->request->params->{assembly},
        chromosome_number    => $c->request->params->{chr},
        start_coord          => $c->request->params->{start},
        end_coord            => $c->request->params->{end},
    };
    # FIXME: generate gff for all design oligos in specified region
    my $oligos = gibson_designs_for_region (
         $schema,
         $params,
    );

    my $gibson_gff = design_oligos_to_gff( $oligos, $params );
    $c->response->content_type( 'text/plain' );
    my $body = join "\n", @{$gibson_gff};
    return $c->response->body( $body );
}


#
# should these go into a util module? (yes)
#
sub crisprs_in_region :Local('crisprs_in_region') Args(0){
    my ($self, $c) = @_;
    
    my $schema = $c->model->schema;
    my $params = { 
        start_coord       => $c->request->params->{start},
        end_coord         => $c->request->params->{end},
        chromosome_number => $c->request->params->{chr},
        assembly_id       => $c->request->params->{assembly},
        exonic_only       => $c->request->params->{exonic_only},       
    };
    
    my $crisprs = crisprs_for_region($schema, $params);

    if(my $design_id = $c->request->params->{design_id}){
        my $five_f = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '5F' });
        my $three_r = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '3R'});
        $params->{design_start} = $five_f->locus->chr_start;
        $params->{design_end} = $three_r->locus->chr_end;
        $c->log->debug(Dumper($params));
    }

    my $crispr_gff = crisprs_to_gff( $crisprs, $params);
    $c->response->content_type( 'text/plain' );
    my $body = join "\n", @{$crispr_gff};
    return $c->response->body( $body );    
}

sub crispr_pairs_in_region :Local('crispr_pairs_in_region') Args(0){
    my ($self, $c) = @_;
    
    my $schema = $c->model->schema;
    my $params = { 
        start_coord       => $c->request->params->{start},
        end_coord         => $c->request->params->{end},
        chromosome_number => $c->request->params->{chr},
        assembly_id       => $c->request->params->{assembly},
        exonic_only       => $c->request->params->{exonic_only},
    };
    
    my $pairs = crispr_pairs_for_region($schema, $params);

    if(my $design_id = $c->request->params->{design_id}){
        my $five_f = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '5F' });
        my $three_r = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '3R'});
        $params->{design_start} = $five_f->locus->chr_start;
        $params->{design_end} = $three_r->locus->chr_end;
        $c->log->debug(Dumper($params));
    }

    my $pairs_gff = crispr_pairs_to_gff( $pairs, $params);
    $c->response->content_type( 'text/plain' );
    my $body = join "\n", @{$pairs_gff};
    return $c->response->body( $body );    
}


#used to retrieve pairs or crisprs from an arrayref of exons
sub _get_exon_attribute {
    my ( $c, $attr, $exon_ids ) = @_;

    _send_error($c, 'No exons given to _get_exon_attribute', 500 ) 
        unless defined $exon_ids;

    #allow an arrayref or a single array
    my @exon_ids = ( ref $exon_ids eq 'ARRAY' ) ? @{ $exon_ids } : ( $exon_ids );

    #make sure attr is pairs or crisprs
    unless ( $attr eq 'pairs' || $attr eq 'crisprs' ) {
        _send_error($c, 'attribute must be pairs or crisprs', 500);
        return;
    }

    my %data;
    for my $exon_id ( @exon_ids ) {
        #make sure the exon exists
        my $exon = $c->model('DB')->resultset('Exon')->find( { ensembl_exon_id => $exon_id } );

        _send_error($c, "Invalid exon id", 400) unless $exon;

        $c->log->debug('Finding ' . $attr . ' for: ' . join( ", ", @exon_ids ));

        my $vals = $exon->$attr;
        _send_error($c, "None found!", 400) unless @{ $vals };

        #store each exons data as an arrayref of hashrefs
        $data{$exon_id} = $vals;
    }

    return \%data;
}

sub _get_species_id {
    my ( $c, $species ) = @_;

    return $c->model('DB')->resultset('Species')->find(
        { id => $species }
    )->numerical_id;
}

#should use FormValidator::Simple or something later
#takes a hashref and an arrayref of required options,
#e.g. check_params_exist( { test => 1 } => [ 'test' ] );
#you must wrap params in scalar otherwise it comes as a hash
sub check_params_exist {
    my ( $c, $params, $options ) = @_;

    for my $option ( @{ $options } ) {
        _send_error($c, "Error: ".ucfirst(lc $option) . " is required", 400 ) unless defined $params->{$option};
    }
}

sub _send_error{
    my ($c, $message, $status) = @_;
    
    $status ||= 400;
    
    $c->log->error($message);
    $c->response->status($status);
    $c->stash->{json_data} = { error => $message };
    $c->detach('View::JSON');
}

1;
