package WGE::Controller::API;
use Moose;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' }


=head1 NAME

WGE::Controller::API - API Controller for WGE

=head1 DESCRIPTION

[enter your description here]

=cut

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
	my ($self, $c) = @_;
	my $params = $c->req->params;
	
	check_params_exist( $c, $params, [ 'pair_id[]' ]);
	
	my @data;
	my $pair_id = $params->{ 'pair_id[]'};
	my @pair_ids = ( ref $pair_id eq 'ARRAY' ) ? @{ $pair_id } : ( $pair_id );

	foreach my $id ( @pair_ids ){
		push @data, "Processing pair $id";
	}
	
	$c->stash->{json_data} = \@data;
	$c->forward('View::JSON');
}
#
# should these go into a util module? (yes)
#

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

        #store each exons data as an arrayref of hashrefs
        $data{$exon_id} = [ map { $_->as_hash } $exon->$attr ];
    }

    return \%data;
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