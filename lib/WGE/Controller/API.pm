package WGE::Controller::API;

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
use Try::Tiny;

use WGE::Util::FindPairs;

BEGIN { extends 'Catalyst::Controller' }

with qw( MooseX::Log::Log4perl WebAppCommon::Crispr::SubmitInterface );

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
                len     => ($_->chr_end - $_->chr_start) - 1,
            }
        } sort { $a->rank <=> $b->rank } $gene->exons;

    #return a list of hashrefs with the matching exon ids and ranks
    $c->stash->{json_data} = { transcript => $gene->canonical_transcript, exons => \@exons };
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

sub pair_off_target_search :Local('pair_off_target_search') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    check_params_exist( $c, $params, [ qw( species left_id right_id ) ] );

    my ( $pair, $crisprs ) = $c->model('DB')->find_or_create_crispr_pair( $params );

    #see what the current pair status is, and decide what to do

    #if its -2 we want to skip, not continue
    if ( $pair->status_id > 0 ) {
        #LOG HERE
        #someone else has already started this one, so don't do anything
        $c->stash->{json_data} = { 'error' => 'Job already started!' };
        $c->forward('View::JSON');
        return;
    }
    elsif ( $pair->status_id == -2 ) {
        #skip it!
        $c->stash->{json_data} = { 'error' => 'Pair has bad crispr' };
        $c->forward('View::JSON');
        return;
    }

    #pair is ready to start

    #its now pending so update the db accordingly
    $pair->update( { status_id => 1 } );

    #if we already have the crisprs pass them on so the method doesn't have to
    #fetch them again
    my @ids_to_search = $pair->_data_missing( $crisprs );

    my $data;
    if ( @ids_to_search ) {
        $c->log->warn( "Finding off targets for: " . join(", ", @ids_to_search) );
        my ( $job_id, $error );
        try {
            die "No pair id" unless $pair->id;
            #we now definitely have a pair, so we would begin the search process
            #something like:

            #we need a create crispr cmd method in the common method too, this won't do.
            my $cmd = [
                "/nfs/team87/farm3_lims2_vms/software/Crisprs/paired_crisprs_wge.sh",
                $pair->id,
                $params->{species},
                join( " ", @ids_to_search ),
            ];

            my $bsub_params = {
                output_dir => dir( '/lustre/scratch109/sanger/team87/crispr_logs/' ),
                id         => $pair->id,
            };

            $job_id = $self->c_run_crispr_search_cmd( $cmd, $bsub_params );
        }
        catch {
            $pair->update( { status_id => -1 } );
            $error = $_;
        };

        if ( $error ) {
            $c->log->warn( "Error getting off targets:" . $error );
            $data = { success => 0, error => $error };
        }
        else {
            $data = { success => 1, job_id => $job_id };
        }
    }
    else {
        $c->log->debug( "Individual crisprs already have off targets, calculating paired offs" );
        #just calculate paired off targets as we already have all the crispr data
        $pair->calculate_off_targets;
        $data = { success => 1 };
    }

    $data->{pair_status} = $pair->status_id;

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
        my @design_ids = split( ' ', $da->design_ids );
        for my $design_id ( @design_ids ) {
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

1;
