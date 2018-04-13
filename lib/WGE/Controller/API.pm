package WGE::Controller::API;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::API::VERSION = '0.112';
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
use POSIX qw( floor );

use WGE::Util::FindPairs;
use WGE::Util::OffTargetServer;
use WGE::Util::FindOffTargets;
use WGE::Util::Haplotype;
use WebAppCommon::Util::EnsEMBL;
use JSON;
use WGE::Util::TimeOut qw(timeout);
use WGE::Util::ExportCSV qw(format_crisprs_for_csv format_pairs_for_csv format_crisprs_for_bed format_pairs_for_bed);

use LWP::UserAgent;


use Sub::Exporter -setup => {
    exports => [ qw(
        handle_public_api
    ) ]
};

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

    $c->log->debug("Gene marker symbol search done");
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
                id      => $_->id,
                exon_id => $_->ensembl_exon_id,
                rank    => $_->rank,
                len     => ($_->chr_end - $_->chr_start) + 1,
            }
        } sort { $a->rank <=> $b->rank } $gene->exons;

    $c->log->debug("Exon search done");
    #return a list of hashrefs with the matching exon ids and ranks
    $c->stash->{json_data} = { transcript => $gene->canonical_transcript, exons => \@exons };
    $c->forward('View::JSON');

    return;
}

sub crispr_by_id :Local('crispr_by_id') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;
    check_params_exist( $c, $params, [ qw( species id ) ]);

    my $ids = $params->{id} ;
    if ( ref $ids ne 'ARRAY' ) {
        $ids = [ $ids ];
    }

    my $data = {};
    my @crisprs = $c->model('DB')->resultset('Crispr')->search( {
        id => { -IN => $ids }
    });

    foreach my $crispr (@crisprs){
        $data->{ $crispr->id } = {
            id                 => $crispr->id,
            chr_name           => $crispr->chr_name,
            chr_start          => $crispr->chr_start,
            chr_end            => $crispr->chr_end,
            seq                => $crispr->seq,
            species_id         => $crispr->species_id,
            pam_right          => $crispr->pam_right,
            off_target_summary => $crispr->off_target_summary,
            exonic             => $crispr->exonic,
            genic              => $crispr->genic,

        };
    }

    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');
    return;
}

sub crispr_seq_by_id :Local('crispr_seq_by_id') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;
    check_params_exist( $c, $params, [ qw( species id ) ]);

    my $ids = $params->{id} ;
    if ( ref $ids ne 'ARRAY' ) {
        $ids = [ $ids ];
    }

    my $data = {};
    my @crisprs = $c->model('DB')->resultset('Crispr')->search( {
        id => { -IN => $ids }
    });

    foreach my $crispr (@crisprs){
        $data->{ $crispr->id } = {
            seq                 => $crispr->seq
        };
    }

    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');
    return;

}

sub off_targets_by_seq :Local('off_targets_by_seq') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    check_params_exist( $c, $params, [ qw( seq pam_right ) ]);

    my $search_params = {
                sequence  => $params->{seq},
                pam_right => $params->{pam_right},
                species   => $params->{species},
    };

    $c->log->debug("Finding off targets by seq: ".Dumper($search_params));

    my $off_target_data;
    try {
        $off_target_data = $self->ots_server->find_off_targets_by_seq($search_params);
    }
    catch ( $e ) {
        $c->log->error( 'Error generating off target data: ' . $e );
        _send_error( $c, $e, 400 );
    }

    $c->log->debug("Off targets by seq search done");

    $c->stash->{json_data} = $off_target_data;
    $c->forward('View::JSON');

    return;
}

sub search_by_seq :Local('search_by_seq') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    my $get_db_data = delete $params->{get_db_data};

    check_params_exist( $c, $params, [ qw( seq pam_right ) ]);

    $c->log->debug("Searching for crisprs by seq");
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

    $c->log->debug("Crispr search by seq done");
    $c->stash->{json_data} = $json;
    $c->forward('View::JSON');

    return;
}

#these two methods are identical, should move the remaining duplication
sub crispr_search :Local('crispr_search') {
    my ($self, $c) = @_;
    my $params = $c->req->params;

    check_params_exist( $c, $params, [ 'exon_id[]' ]);

    $c->log->debug("Doing crispr_search");

    my $crispr_data = _get_exon_attribute(
        $c,
        "crisprs",
        $params->{ 'exon_id[]' },
        undef, #species which is optional
        $params->{ flank }
    );
    $c->log->debug("crispr_search done");

    #default to json, but allow csv
    if ( exists $params->{csv} and $params->{csv} ) {
        my @crispr_list;
        while ( my ( $exon_id, $crisprs ) = each %{ $crispr_data } ) {
            for my $crispr ( @{ $crisprs } ) {
                push @crispr_list, $crispr;
            }
        }

        my $show_exon_id = 1;
        my $csv_data = format_crisprs_for_csv(\@crispr_list, $show_exon_id);
        $c->log->debug( "Total CSV rows:" . scalar( @$csv_data ) );


        #format array of exons properly
        my $exons = $params->{'exon_id[]'};
        if ( ref $exons eq 'ARRAY' ) {
            #limit exon string to 50 characters
            $exons = substr( join("-", @{ $params->{'exon_id[]'} }), 0, 50 );
        }

        $c->stash(
            filename     => "WGE-" . $exons . "-crisprs.tsv",
            data         => $csv_data,
            current_view => 'CSV',
        );
    }
    else{
        $c->stash->{json_data} = $crispr_data;
        $c->forward('View::JSON');
    }

    return;
}

sub pair_search :Local('pair_search') {
    my ($self, $c) = @_;
    my $params = $c->req->params;

    check_params_exist( $c, $params, [ 'exon_id[]' ]);

    $c->log->debug("doing pair_search");
    my $pair_data = _get_exon_attribute(
        $c,
        "pairs",
        $params->{ 'exon_id[]' },
        $params->{ flank },
    );

    #default to json, but allow csv
    if ( exists $params->{csv} and $params->{csv} ) {
        my @pair_list;
        while ( my ( $exon_id, $pairs ) = each %{ $pair_data } ) {
            for my $pair ( @{ $pairs } ) {
                push @pair_list, $pair;
            }
        }
        my $show_exon_id = 1;
        my $csv_data = format_pairs_for_csv(\@pair_list, $show_exon_id);


        $c->log->debug( "Total CSV rows:" . scalar( @$csv_data ) );

        #format array of exons properly
        my $exons = $params->{'exon_id[]'};
        if ( ref $exons eq 'ARRAY' ) {
            #limit exon string to 50 characters
            $exons = substr( join("-", @{ $params->{'exon_id[]'} }), 0, 50 );
        }

        $c->stash(
            filename     => "WGE-" . $exons . "-pairs.tsv",
            data         => $csv_data,
            current_view => 'CSV',
        );
    }
    else {
        $c->stash->{json_data} = $pair_data;
        $c->forward('View::JSON');
    }

    $c->log->debug("pair_search done");
    return;
}

sub individual_off_target_search :Local('individual_off_target_search') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;
    check_params_exist( $c, $params, [ qw( species ids[] ) ] );

    try {
        my $data = $self->ot_finder->run_individual_off_target_search(
            $c->model('DB'),
            $params->{species},
            $params->{'ids[]'}
        );

        $c->stash->{json_data} = $data // {};
    }
    catch ( $e ) {
        $e = $e->as_string if ref $e;
        $c->stash->{json_data} = { error => $e };
    }

    $c->forward('View::JSON');

    return;
}

# This differs from individual_off_target_search as it returns the off-target
# summary and list for all crisprs queried, not just those that have been
# added to the database following the call to the CRISPR-Analyser
sub crispr_off_targets :Local('crispr_off_targets'){
    my ($self, $c) = @_;

    my $params = $c->req->params;
    check_params_exist( $c, $params, [ qw( species id ) ] );

    my $ids = $params->{id} ;
    if ( ref $ids ne 'ARRAY' ) {
        $ids = [ $ids ];
    }

    try {
        my $data = $self->ot_finder->run_individual_off_target_search(
            $c->model('DB'),
            $params->{species},
            $ids,
        );
    }
    catch ($e){
        $c->stash->{json_data} = { error => $e };
        $c->forward('View::JSON');
        return;
    }

    my $data = {};
    my @crisprs = $c->model('DB')->resultset('Crispr')->search({
        id => { '-in' => $ids }
    });

    foreach my $crispr (@crisprs){
        $data->{ $crispr->id } = {
            id                 => $crispr->id,
            off_targets        => $crispr->off_target_ids,
            off_target_summary => $crispr->off_target_summary,
        };

        if($c->req->param('with_detail')){
            $data->{ $crispr->id }->{off_target_details} = {};
            my $details = $data->{ $crispr->id }->{off_target_details};
            my $target_seq = $crispr->target_seq;
            $c->log->debug("Target seq: $target_seq");

            foreach my $ot ($crispr->off_targets){
                my $mm_count = ( $target_seq ^ $ot->seq ) =~ tr/\0//c;
                $details->{$ot->id} = {
                    chr_name  => $ot->chr_name,
                    chr_start => $ot->chr_start,
                    chr_end   => $ot->chr_end,
                    pam_right => $ot->pam_right,
                    seq       => $ot->seq,
                    mismatch_count => $ot->mismatches($target_seq),
                };
            }
        }
    }

    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');
    return;
}

sub pair_off_target_search :Local('pair_off_target_search') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    check_params_exist( $c, $params, [ qw( species left_id right_id ) ] );

    my $data = $self->ot_finder->run_pair_off_target_search($c->model('DB'), $params);

    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');

    return;
}

# This differs from pair_off_target_search as it returns the off target information
# for the crispr_pair ID queried
sub crispr_pair_off_targets :Local('crispr_pair_off_targets') {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    check_params_exist( $c, $params, [ qw( species left_id right_id ) ] );

    my $data = $self->ot_finder->run_pair_off_target_search($c->model('DB'), $params);

    if($data->{success}){
        my $off_target_data;
        my $pair = $c->model('DB')->find_crispr_pair($params);

        my @off_target_ids;
        foreach my $off_target ($pair->off_targets){
            push @off_target_ids, $off_target->{left_crispr}->{id}
                                  ."_"
                                  .$off_target->{right_crispr}->{id};
        }

        my $pair_data = {
            $pair->id => {
                id                 => $pair->id,
                off_target_summary => $pair->off_target_summary,
                off_targets        => \@off_target_ids,
            }
        };

        $c->stash->{json_data} = $pair_data;
    }
    else{
        $c->stash->{json_data} = $data;
    }


    $c->forward('View::JSON');

    return;
}

sub exon_off_target_search :Local('exon_off_target_search'){
    my ( $self, $c ) = @_;

    my $params = $c->req->params;

    check_params_exist( $c, $params, [ qw( exon_id species_id ) ] );

    # Pass $c to the method as it spawns child processes which need to detach the request
    my $data = $self->ot_finder->update_exon_off_targets( $c->model('DB'), $params, $c );

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

    $c->log->debug("Finding designs in region ".$params->{chromosome_number}.":".$params->{start_coord}."-".$params->{end_coord});
    # FIXME: generate gff for all design oligos in specified region
    my $oligos = gibson_designs_for_region (
         $schema,
         $params,
    );

    my $gibson_gff = design_oligos_to_gff( $oligos, $params );

    $c->log->debug("designs in regions search done");

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
        species_id        => $c->request->params->{species_id},
        start_coord       => $c->request->params->{start},
        end_coord         => $c->request->params->{end},
        chromosome_number => $c->request->params->{chr},
        assembly_id       => $c->request->params->{assembly},
        crispr_filter     => $c->request->params->{crispr_filter},
        flank_size        => $c->request->params->{flank_size},
    };

    my $region = $params->{chromosome_number}.":".$params->{start_coord}."-".$params->{end_coord};
    $c->log->debug("Finding crisprs in region $region");

    # Show only bookmarked crisprs
    if($c->request->params->{bookmarked_only}){
        $params->{user} = $c->user;
    }

    my $crisprs = crisprs_for_region($schema, $params);

    # Can request CSV download, otherwise continue to generate gff
    if($c->request->params->{csv}){
        my $csv_data = format_crisprs_for_csv([$crisprs->all]);
        $c->stash(
            filename     => "WGE-" . $region . "-crisprs.tsv",
            data         => $csv_data,
            current_view => 'CSV',
        );
        return;
    }

    if($c->request->params->{bed}){
        my $bed_data = format_crisprs_for_bed([$crisprs->all]);
        $c->stash(
            filename        => "WGE-chr" . $region . "-crisprs.bed",
            data            => $bed_data,
            current_view    => 'CSV',
        );
        return;

    }

    if(my $design_id = $c->request->params->{design_id}){
        my $five_f = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '5F' });
        my $three_r = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '3R'});
        $params->{design_start} = $five_f->locus->chr_start;
        $params->{design_end} = $three_r->locus->chr_end;
    }

    my $crispr_gff = crisprs_to_gff( $crisprs, $params);

    $c->log->debug("crisprs in region search done");

    $c->response->content_type( 'text/plain' );
    my $body = join "\n", @{$crispr_gff};
    return $c->response->body( $body );
}

sub crispr_pairs_in_region :Local('crispr_pairs_in_region') Args(0){
    my ($self, $c) = @_;

    my $schema = $c->model->schema;
    my $params = {
        species_id        => $c->request->params->{species_id},
        start_coord       => $c->request->params->{start},
        end_coord         => $c->request->params->{end},
        chromosome_number => $c->request->params->{chr},
        assembly_id       => $c->request->params->{assembly},
        crispr_filter     => $c->request->params->{crispr_filter},
        flank_size        => $c->request->params->{flank_size},
    };

    my $region = $params->{chromosome_number}.":".$params->{start_coord}."-".$params->{end_coord};
    $c->log->debug("Finding crispr pairs in region $region");

    my $pairs;
    # Show only bookmarked crispr pairs
    if($c->request->params->{bookmarked_only}){
        $params->{user} = $c->user;
        $pairs = bookmarked_pairs_for_region($schema, $params);
    }
    else{
        $pairs = crispr_pairs_for_region($schema, $params);
    }

    # Can request CSV download, otherwise continue to generate gff
    if($c->request->params->{csv}){
        my $csv_data = format_pairs_for_csv($pairs);
        $c->stash(
            filename     => "WGE-" . $region . "-pairs.tsv",
            data         => $csv_data,
            current_view => 'CSV',
        );
        return;
    }

    if($c->request->params->{bed}){
        my $bed_data = format_pairs_for_bed($pairs);
        $c->stash(
            filename        => "WGE-chr" . $region . "-pairs.bed",
            data            => $bed_data,
            current_view    => 'CSV',
        );
        return;

    }

    if(my $design_id = $c->request->params->{design_id}){
        my $five_f = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '5F' });
        my $three_r = $c->model->c_retrieve_design_oligo({ design_id => $design_id, oligo_type => '3R'});
        $params->{design_start} = $five_f->locus->chr_start;
        $params->{design_end} = $three_r->locus->chr_end;
    }

    my $pairs_gff = crispr_pairs_to_gff( $pairs, $params);

    $c->log->debug("crispr pairs in region search done");

    $c->response->content_type( 'text/plain' );
    my $body = join "\n", @{$pairs_gff};
    return $c->response->body( $body );
}

sub haplotypes_for_region :Local('haplotypes_for_region') Args(0) {
    my ($self, $c) = @_;

    my $params = $c->request->params();

    $c->log->debug("Finding haplotypes for region " . $params->{chr_name}.":".$params->{chr_start}."-".$params->{chr_end});

    my $haplotype = WGE::Util::Haplotype->new( { species => $params->{species} } );

    my $haplo_features = $haplotype->retrieve_haplotypes(
        $c->model('DB'),
        $params
    );

    my $updated_haplo_features = [];

    foreach my $haplo_feature ( @{$haplo_features} ) {
        my $phased_haplo = $haplotype->phase_haplotype(
            $haplo_feature,
            $params
        );

        push(@{$updated_haplo_features}, $phased_haplo);
    }

    $c->log->debug("Finished finding haplotypes for region");

    $c->stash->{'json_data'} = $updated_haplo_features;

    $c->log->debug("Saved feature to stash");

    $c->forward('View::JSON');

    return;
}




sub variation_for_region :Local('variation_for_region') Args(0) {
    my ($self, $c) = @_;

    my $model = $c->model('DB');

    my $params = ();
    $params->{species}      = $c->request->params->{'species'};
    $params->{assembly_id}  = $c->request->params->{'assembly'};
    $params->{chr_number}   = $c->request->params->{'chr_name'};
    $params->{start_coord}  = $c->request->params->{'chr_start'};
    $params->{end_coord}    = $c->request->params->{'chr_end'};

    $c->log->debug("Finding variation for region ".$params->{chr_number}.":".$params->{start_coord}."-".$params->{end_coord});

    use WGE::Util::Variation;
    my $variation = WGE::Util::Variation->new ( {'species' => $params->{'species'}} );

    my $var_feature = $variation->variation_for_region(
         $model,
         $params,
    );

    $c->log->debug("variation for region done");

    $c->stash->{'json_data'} = $var_feature;

    $c->forward('View::JSON');

    return ;

}

sub val_in_range {
    my ( $val, $min, $max ) = @_;

    return ( $val >= $min ) && ( $val <= $max );
};

sub translation_for_region :Local('translation_for_region') Args(0) {
    my ( $self, $c ) = @_;

    my $params = $c->request->params;

    my $ensembl = WebAppCommon::Util::EnsEMBL->new( species => $params->{species} );

    $c->log->debug( "translation_for_region: ".$params->{chr_name} . ":" . $params->{chr_start} . "-" . $params->{chr_end} );

    my @features;

    timeout(5,sub{
        my $slice = $ensembl->slice_adaptor->fetch_by_region(
            'chromosome',
            $params->{chr_name},
            $params->{chr_start},
            $params->{chr_end},
        );

        my @genes = @{ $slice->get_all_Genes_by_type('protein_coding') };


        $c->log->debug( "Found " . scalar( @genes ) . " genes for region" );


        for my $gene ( @genes ) {
            try {
                push @features, $self->_process_gene( $c, $gene );
            }
            catch ( $e ) {
                $c->log->error( $e );
                #$c->stash->{json_data} = { error => $e };
            }
        }
    });

    $c->log->debug("translation_for_region done");
    $c->stash->{json_data} = \@features;
    $c->forward('View::JSON');

    return;
}

sub _process_gene {
    my ( $self, $c, $gene ) = @_;

    $c->log->debug( "Gene: " . $gene->stable_id . " (" . $gene->external_name . ")" );
    my $transcript = $gene->canonical_transcript;
    my $translation = $transcript->translation;

    next unless $translation;

    #ensembl doesn't add the stop codon
    my $trans_seq = $translation->seq . "*";
    my $nuc_seq = $transcript->translateable_seq;

    die "Number of nucleotides does not match the number of amino acids"
        unless length( $nuc_seq ) / 3 == length( $trans_seq );

    my @features;
    my $rank = 0;
    my $start_index = 1;
    my @exons = @{ $transcript->get_all_Exons };
    for my $exon ( @exons ) {
        ++$rank;
        my $start = $exon->coding_region_start( $transcript );
        my $end   = $exon->coding_region_end( $transcript );
        next unless $start and $end; #skip non coding exons

        #see if there are bases spanning two exons,
        #and extract them into here if so
        my ( $start_base, $end_base );

        #use a closure here so we don't have to pass start/end around all the time
        #base_data is optional as sometimes we don't want to set it
        my $adjust_start_coordinates = sub {
            my ( $amount, $base_data ) = @_;
            if ( $exon->strand == 1 ) {
                $start += $amount;
                $start_base = $base_data if $base_data;
            }
            elsif ( $exon->strand == -1 ) {
                $end -= $amount;
                $end_base = $base_data if $base_data;
            }
            else {
                die "Unknown strand";
            }
        };

        my $adjust_end_coordinates = sub {
            my ( $amount, $base_data ) = @_;
            if ( $exon->strand == 1 ) {
                $end -= $amount;
                $end_base = $base_data if $base_data;
            }
            elsif ( $exon->strand == -1 ) {
                $start += $amount;
                $start_base = $base_data if $base_data;
            }
            else {
                die "Unknown strand";
            }
        };

        #skip unless the exon is within our window --
        # we can't do this because we actually NEED to process every exon first.
        #could do this at the end, but whats the point, may as well include all the data.
        #next unless val_in_range( $params->{chr_start}, $start, $end )
        #         || val_in_range( $start, $params->{chr_start}, $params->{chr_end} );

        if ( $exon->phase > 0 && $rank == 1 ) {
            #some fruity genes have a start phase that isn't 1 (ENSG00000249624 - AP000295.9)
            #if that is the case just strip off those first few bases because we can't do anything else

            #these cause too many problems, so instead of trying to fix them
            #we just won't show this exon. ive left the code that "fixes" it below
            die "First exon has a start phase that isn't 0";

            #remove first so called "amino acid"
            #also adjust the start and end to what they are now so length calculations work
            $nuc_seq = substr( $nuc_seq, 3 );
            $adjust_start_coordinates->( 3 - $exon->phase );
        }
        elsif ( $exon->phase > 0 ) {
            #for start we have to take it off 3 to get the actual
            #number of nucleotides in this exon
            my $num_nucs = 3 - $exon->phase;

            #there is an amino acid at the start we need to take
            my $data = {
                aa  => substr( $trans_seq, 0, 1 ),
                len => $num_nucs,
                codon => substr( $nuc_seq, 0, 3 ), #first 3 bases are the complete nucleotide
            };

            #also remove it from the sequences as we don't want it in the counts
            $trans_seq = substr( $trans_seq, 1 );
            $nuc_seq = substr( $nuc_seq, 3 );

            $adjust_start_coordinates->( $num_nucs, $data );
        }

        if ( $exon->end_phase > 0 ) {
            #we don't truncate the trans_seq here cause the next exon needs the
            #amino acid too.
            #my $data = { aa => substr( $trans_seq, 0, 1 ), len => $exon->end_phase };

            #dont set the start_base/end_base yet because we need to truncate the seq first
            $adjust_end_coordinates->( $exon->end_phase );
        }

        my $length = ($end - $start) + 1;

        #the last exon can have a partial codon at the end,
        #if so just strip the bases
        if ( $rank == @exons ) {
            my $remainder = $length % 3;
            if ( $remainder != 0 ) {
                die "Last exon has partial codon at the end";
                $nuc_seq = substr( $nuc_seq, 0, -$remainder );
            }

            $length -= $remainder;
        }

        die "something has gone horribly wrong" if $length % 3 != 0;

        my $num_amino_acids = $length / 3;

        # $c->log->debug("Exon length $length, taking $num_amino_acids, rank $rank");
        # $c->log->debug("start phase: " . $exon->phase . ", end_phase: " . $exon->end_phase);

        die length($trans_seq) . " bases left, want $num_amino_acids"
            if $num_amino_acids > length( $trans_seq );

        #remove the first x bases from our transcript sequence string
        my $seq = substr( $trans_seq, 0, $num_amino_acids );
        $trans_seq = substr( $trans_seq, $num_amino_acids );

        #also extract the equivalent nucleotides
        my $nucleotides = substr( $nuc_seq, 0, $num_amino_acids * 3 );
        $nuc_seq = substr( $nuc_seq, $num_amino_acids * 3 );

        #first base of what is left is now the 'end base' we're interested in
        my $additional_aa = 0;
        if ( $exon->end_phase > 0 ) {
            $additional_aa = 1; #so we can identify if we need to add one more to start index
            #we don't truncate the trans_seq here cause the next exon needs the
            #amino acid too.
            my $data = {
                aa  => substr( $trans_seq, 0, 1 ),
                len => $exon->end_phase,
                codon => substr( $nuc_seq, 0, 3 ),
            };
            $adjust_end_coordinates->( 0, $data );
        }

        # $c->log->debug($seq . " (" . length($seq) . ")");
        # $c->log->debug($trans_seq . " (" . length($trans_seq) . ")");

        push @features, {
            id              => $exon->stable_id,
            transcript      => $transcript->stable_id,
            protein         => $translation->stable_id,
            gene            => $gene->stable_id,
            chr_name        => $c->request->params->{chr_name},
            start           => $start,
            end             => $end,
            strand          => $transcript->strand,
            start_base      => $start_base,
            end_base        => $end_base,
            sequence        => $seq,
            nucleotides     => $nucleotides,
            start_phase     => $exon->phase,
            end_phase       => $exon->end_phase,
            rank            => $rank,
            start_index     => $start_index,
            num_amino_acids => $num_amino_acids,
        };

        $start_index += $num_amino_acids + $additional_aa;
    }

    $c->log->debug("$rank exons processed");
    $c->log->debug( length( $trans_seq ) . " bases left of transcript!") if $trans_seq;

    return @features;
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

        my $exon;
        if ( $c->req->params->{species} ) {
            ( $exon ) = $c->model('DB')->resultset('Exon')->search(
                {
                    ensembl_exon_id => $exon_id,
                    'species.id'    => $c->req->params->{species},
                },
                { join => { gene => 'species' } }
            );
        }
        else {
            #because Human/Grch38 have overlapping exons its possible we get two back in human.
            #we have no way of knowing which one it is unless the user specifies a species
            my @exons = $c->model('DB')->resultset('Exon')->search( { ensembl_exon_id => $exon_id } );
            _send_error( $c, "Found multiple exons, please provide a species.", 400 ) if @exons > 1;
            $exon = $exons[0];
        }

        #my $exon = $c->model('DB')->resultset('Exon')->find( { ensembl_exon_id => $exon_id } );

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

sub announcements :Local('announcements') {
    my ($self, $c) = @_;
    my $message = handle_public_api();
    return $c->response->body($message);
}

sub handle_public_api {
    my ($self, $c) = @_;
    print Dumper "Entered";
    my $agent = LWP::UserAgent->new;
    my $url = "http://www.sanger.ac.uk/htgt/lims2/public_api/announcements/?sys=wge";

    my $req = HTTP::Request->new(GET => $url);
    $req->header('content-type' => 'application/json');

    my $response = $agent->request($req);
    if ($response->is_success) {
        my $message = $response->decoded_content;
        return $message;
    }
}
1;
