package WGE::Controller::API;

use Moose;
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

[enter your description here]

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

    #if the pair doesn't exist create it, note that this is subject to a race condition
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
	
# 	$c->stash->{json_data} = \@data;
# 	$c->forward('View::JSON');
# }
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
