package WGE::Controller::API;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::API::VERSION = '0.040';
}
## use critic


use Moose;
use WGE::Util::GenomeBrowser qw(
    gibson_designs_for_region
    design_oligos_to_gff
    crisprs_for_region
    crisprs_to_gff
    crispr_pairs_for_region
    crispr_pairs_to_gff
    bookmarked_pairs_for_region
    );
use namespace::autoclean;
use Data::Dumper;
use Path::Class;
use TryCatch;

use WGE::Util::FindPairs;
use WGE::Util::OffTargetServer;
use WGE::Util::FindOffTargets;

BEGIN { extends 'Catalyst::Controller' }

with qw( MooseX::Log::Log4perl WebAppCommon::Crispr::SubmitInterface );

has pair_finder => (
    is         => 'ro',
    isa        => 'WGE::Util::FindPairs',
    lazy_build => 1,
);

sub _build_pair_finder {
    return WGE::Util::FindPairs->new;
}

has ots_server => (
    is => 'ro',
    isa => 'WGE::Util::OffTargetServer',
    lazy_build => 1,
);

sub _build_ots_server {
    return WGE::Util::OffTargetServer->new;
}

has ot_finder => (
    is => 'ro',
    isa => 'WGE::Util::FindOffTargets',
    lazy_build => 1,
);

sub _build_ot_finder {
    return WGE::Util::FindOffTargets->new;
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

    return;
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

    return;
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
                len     => ($_->chr_end - $_->chr_start) + 1,
            }
        } sort { $a->rank <=> $b->rank } $gene->exons;

    #return a list of hashrefs with the matching exon ids and ranks
    $c->stash->{json_data} = { transcript => $gene->canonical_transcript, exons => \@exons };
    $c->forward('View::JSON');

    return;
}

sub search_by_seq :Local('search_by_seq') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    my $get_db_data = delete $params->{get_db_data};

    check_params_exist( $c, $params, [ qw( seq pam_right ) ]);

    my $json = $self->ots_server->search_by_seq(
        {
            sequence  => $params->{seq},
            pam_right => $params->{pam_right},
            species   => $params->{species},
        }
    );

    #it will be a hash if there was an error
    if ( ref $json eq 'ARRAY' && $get_db_data ) {
        for my $id ( @{ $json } ) {
            #replace id with a crispr hash
            $id = $c->model('DB')->resultset('Crispr')->find( $id )->as_hash;
        }
    }

    $c->stash->{json_data} = $json;
    $c->forward('View::JSON');

    return;
}

#these two methods are identical, should move the remaining duplication
sub crispr_search :Local('crispr_search') {
    my ($self, $c) = @_;
    my $params = $c->req->params;

    check_params_exist( $c, $params, [ 'exon_id[]' ]);

    $c->stash->{json_data} = _get_exon_attribute(
        $c,
        "crisprs",
        $params->{ 'exon_id[]' },
        undef, #species which is optional
        $params->{ flank }
    );

    $c->forward('View::JSON');

    return;
}

sub pair_search :Local('pair_search') {
    my ($self, $c) = @_;
    my $params = $c->req->params;

    check_params_exist( $c, $params, [ 'exon_id[]' ]);

    my $pair_data = _get_exon_attribute(
        $c,
        "pairs",
        $params->{ 'exon_id[]' },
        $params->{ flank },
    );

    #default to json, but allow csv
    if ( exists $params->{csv} and $params->{csv} ) {
        my @csv_data;

        my @fields = qw( exon_id spacer pair_status summary pair_id );

        my @crispr_fields = qw( id location seq off_target_summary );

        for my $orientation ( qw( l r ) ) {
            push @fields, map { $orientation . "_" . $_ } @crispr_fields;
        }

        push @csv_data, \@fields;

        while ( my ( $exon_id, $pairs ) = each %{ $pair_data } ) {
            for my $pair ( @{ $pairs } ) {
                my ( $status, $summary ) = ("Not started", "");

                if ( $pair->{db_data} ) {
                    $status  = $pair->{db_data}{status} if $pair->{db_data}{status};
                    $summary = $pair->{db_data}{off_target_summary} if $pair->{db_data}{off_target_summary};
                }

                my @row = (
                    $exon_id,
                    $pair->{spacer},
                    $status,
                    $summary,
                    $pair->{id},
                );

                #add all the individual crispr fields for both crisprs
                for my $dir ( qw( left_crispr right_crispr ) ) {
                    #mirror ensembl location format
                    $pair->{$dir}{location} = $pair->{$dir}{chr_name}  . ":"
                                      . $pair->{$dir}{chr_start} . "-"
                                      . $pair->{$dir}{chr_end};

                    push @row, map { $pair->{$dir}{$_} || "" } @crispr_fields;
                }

                push @csv_data, \@row;
            }
        }

        $c->log->debug( "Total CSV rows:" . scalar( @csv_data ) );

        #format array of exons properly
        my $exons = $params->{'exon_id[]'};
        if ( ref $exons eq 'ARRAY' ) {
            #limit exon string to 50 characters
            $exons = substr( join("-", @{ $params->{'exon_id[]'} }), 0, 50 );
        }

        $c->stash(
            filename     => "WGE-" . $exons . "-pairs.tsv",
            data         => \@csv_data,
            current_view => 'CSV',
        );
    }
    else {
        $c->stash->{json_data} = $pair_data;
        $c->forward('View::JSON');
    }

    return;
}

sub individual_off_target_search :Local('individual_off_target_search') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;
    check_params_exist( $c, $params, [ qw( species ids ) ] );



    my $data = $self->ot_finder->run_individual_off_target_search( $c->model('DB'), $params );

    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');

    return;
}

sub pair_off_target_search :Local('pair_off_target_search') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    check_params_exist( $c, $params, [ qw( species left_id right_id ) ] );

    my $data = $self->ot_finder->run_pair_off_target_search($c->model('DB'),$params);

    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');

    return;
}

sub exon_off_target_search :Local('exon_off_target_search'){
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    check_params_exist( $c, $params, [ qw( id )] );

    # Pass $c to the method as it spawns child processes which need to detach the request
    my $data = $self->ot_finder->update_exon_off_targets($c->model('DB'),$params, $c);

    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');

    return;
}

sub region_off_target_search :Local('region_off_target_search'){
    my ( $self, $c ) = @_;
    my $params = $c->req->params;

    check_params_exist( $c, $params, [ qw( start_coord end_coord assembly_id chromosome_number )] );

    my $data;
    if($params->{end_coord} - $params->{start_coord} > 3000){
        # 3 kb max search region (3 kb is also the max size for which genoverse will display crisprs)
        $data->{error_msg} = "Off-target search region is too large. You must select a region less than 3kb.";
    }
    else{
        try{
            # Pass $c to the method as it spawns child processes which need to detach the request
            $data = $self->ot_finder->update_region_off_targets($c->model('DB'),$params, $c);
        }
        catch ($e){
            $data->{error_msg} = "Off-target search failed with error: $e";
        }
    }

    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');

    return;
}

# FIXME: we have a crispr_pair getter in REST module too but it requires login..
sub pair :Local('pair'){
    my ( $self, $c ) = @_;

    my $params = $c->req->params;
    my $data = {};

    check_params_exist( $c, $params, [ qw( id ) ] );
    my $id = $params->{id};

    my $pair = $c->model('DB')->resultset('CrisprPair')->find({ id => $id });
    if($pair){
        $data = { success => 1, crispr_pair => $pair->as_hash({ db_data => 1 }) };
    }
    else{
        $data = { success => 0, error => "crispr pair $id not found"};
    }


    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');

    return;
}

sub design_attempt_status :Chained('/') PathPart('design_attempt_status') Args(1) {
    my ( $self, $c, $da_id ) = @_;

    # require authenticated user for this request?

    $c->log->debug("Getting status for design attempt $da_id");

    my $da = $c->model->c_retrieve_design_attempt( { id => $da_id } );
    my $status = $da->status;
    my $design_links;
    if ( $status eq 'success' ) {
        for my $design_id ( @{ $da->design_ids } ) {
            my $link = $c->uri_for('/view_gibson_design', { design_id => $design_id } )->as_string;
            $design_links .= '<a href="' . $link . '">'. $design_id .'</a><br>';
        }
    }

    $c->stash->{json_data} = { status => $status, designs => $design_links };
    $c->forward('View::JSON');

    return;
}

sub designs_in_region :Local('designs_in_region') Args(0){
    my ($self, $c) = @_;

    my $schema = $c->model->schema;
    my $params = {
        assembly_id          => $c->request->params->{assembly},
        chromosome_number    => $c->request->params->{chr},
        start_coord          => $c->request->params->{start},
        end_coord            => $c->request->params->{end},
        user                 => $c->user,
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
        crispr_filter     => $c->request->params->{crispr_filter},
        flank_size        => $c->request->params->{flank_size},
    };

    # Show only bookmarked crisprs
    if($c->request->params->{bookmarked_only}){
        $params->{user} = $c->user;
    }

    my $crisprs = crisprs_for_region($schema, $params);

    if(my $design_id = $c->request->params->{design_id}){
        my $five_f = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '5F' });
        my $three_r = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '3R'});
        $params->{design_start} = $five_f->locus->chr_start;
        $params->{design_end} = $three_r->locus->chr_end;
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
        crispr_filter     => $c->request->params->{crispr_filter},
        flank_size        => $c->request->params->{flank_size},
    };

    my $pairs;
    # Show only bookmarked crispr pairs
    if($c->request->params->{bookmarked_only}){
        $params->{user} = $c->user;
        $pairs = bookmarked_pairs_for_region($schema, $params);
    }
    else{
        $pairs = crispr_pairs_for_region($schema, $params);
    }

    if(my $design_id = $c->request->params->{design_id}){
        my $five_f = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '5F' });
        my $three_r = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '3R'});
        $params->{design_start} = $five_f->locus->chr_start;
        $params->{design_end} = $three_r->locus->chr_end;
    }

    my $pairs_gff = crispr_pairs_to_gff( $pairs, $params);
    $c->response->content_type( 'text/plain' );
    my $body = join "\n", @{$pairs_gff};
    return $c->response->body( $body );
}


#used to retrieve pairs or crisprs from an arrayref of exons
#args should just be flank generally.
sub _get_exon_attribute {
    my ( $c, $attr, $exon_ids, @args ) = @_;

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

        #sometimes we get a hash, sometimes an object.
        #if its an object then call as hash
        my @vals = map { blessed $_ ? $_->as_hash : $_ } $exon->$attr( @args );
        $_->{ensembl_exon_id} = $exon_id for @vals;

        _send_error($c, "None found!", 400) unless @vals;

        #store each exons data as an arrayref of hashrefs
        $data{$exon_id} = \@vals;
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

    return;
}

sub _send_error{
    my ($c, $message, $status) = @_;

    $status ||= 400;

    $c->log->error($message);
    $c->response->status($status);
    $c->stash->{json_data} = { error => $message };
    $c->detach('View::JSON');

    return;
}

# Use this to check that forking is working as expected
sub fork_test :Local('fork_test') Args(0){
   my ($self, $c) = @_;

   $c->log->debug("preparing for first fork");
   local $SIG{CHLD} = 'IGNORE';

   my $pid1 = fork;
   if($pid1){
       $c->log->debug("i have a first child with id $pid1");
   }
   elsif($pid1 == 0){
       $c->log->debug("i am the first child process");
       $c->detach();
       exit 0;
   }
   else{
       die "could not fork - $!";
   }

   $c->log->debug("preparing for second fork");
   my $pid2 = fork;
   if($pid2){
       $c->log->debug("i have a second child with id $pid2");
   }
   elsif($pid2 == 0){
       $c->log->debug("i am the second child process");
       $c->detach();
       exit 0;
   }
   else{
       die "could not fork - $!";
   }
   $c->log->debug("..and back in the parent again");
   $c->stash->{json_data} = { fork_test => "complete" };
   $c->log->debug("i have stashed json_data");
   $c->forward('View::JSON');
}
1;
