package WGE::Util::CrisprOligoSelection;

use strict;
use warnings;

=head1 NAME

WGE::Util::OligoSelection

=head1 DESCRIPTION

Uses Primer3 to select sequencing primers for a crispr pair.

Uses Primer3 and BWA to select PCR primers to generate a product for the sequencing primers
to work with.

=cut

use Sub::Exporter -setup => {
    exports => [ qw(
        gibson_design_oligos_rs
        oligos_for_gibson
        oligos_for_crispr_pair
        pick_crispr_primers
    ) ]
};

use WGE::Exception;

use Log::Log4perl qw(:easy);


BEGIN {
    # WGE environment variables start with WGE_
    # but DesignCreate needs 'PRIMER3_CMD'
    local $ENV{'PRIMER3_CMD'} = $ENV{'LIMS2_PRIMER3_COMMAND_PATH'};
}
use DesignCreate::Util::Primer3;
use DesignCreate::Util::BWA;

use Bio::SeqIO;
use Path::Class;
use Bio::EnsEMBL::Registry;

my $registry = 'Bio::EnsEMBL::Registry';

$registry->load_registry_from_db(
        -host => $ENV{WGE_ENSEMBL_HOST} || 'ensembldb.internal.sanger.ac.uk',
        -user => $ENV{WGE_ENSEMBL_USER} || 'anonymous'
    );



=head pick_PCR_primers_for_crisprs
    given location of crispr primers as an input,
    search for primers to generate a PCR product covering the region of the crispr primers
    This is modeled on the genotyping primers and therefore includes a genomic check
=cut


sub pick_crispr_PCR_primers {
    my $params = shift;

    my $schema = $params->{'schema'};
    my $well_id = $params->{'well_id'};
    my $crispr_primers = $params->{'crispr_primers'};
    my $species = $params->{'species'};
    my $repeat_mask = $params->{'repeat_mask'};
    my %failed_primer_regions;
    # Return the design oligos as well so that we can report them to provide context later on
    my ($region_bio_seq, $target_sequence_mask, $target_sequence_length )
        = get_crispr_PCR_EnsEmbl_region( {
                schema => $schema,
                crispr_primers => $crispr_primers,
                species => $species,
                repeat_mask => $repeat_mask,
            } );
    my $p3 = DesignCreate::Util::Primer3->new_with_config(
        configfile => $ENV{ 'LIMS2_PRIMER3_PCR_CRISPR_PRIMER_CONFIG' },
        primer_product_size_range => $target_sequence_length . '-' . ($target_sequence_length + 500),
    );
    my $dir_out = dir( $ENV{ 'LIMS2_PRIMER_SELECTION_DIR' } );
    my $logfile = $dir_out->file( $well_id . '_pcr_oligos.log');

    my ( $result, $primer3_explain ) = $p3->run_primer3( $logfile->absolute, $region_bio_seq, # bio::seqI
            {
                SEQUENCE_TARGET => $target_sequence_mask ,
            } );
    if ( $result->num_primer_pairs ) {
        INFO ( "$well_id genotyping primer region primer pairs: " . $result->num_primer_pairs );
    }
    else {
        INFO ( "Failed to generate pcr primer pairs for $well_id" );
        $failed_primer_regions{$well_id} = $primer3_explain;
    }


    my $primer_data = parse_primer3_results( $result );

    use DesignCreate::Exception::Primer3FailedFindOligos;

    if (%failed_primer_regions) {
        DesignCreate::Exception::Primer3FailedFindOligos->throw(
            regions             => [ keys %failed_primer_regions ],
            primer_fail_reasons => \%failed_primer_regions,
        );
    }

    my $primer_passes = pcr_genomic_check( $well_id, $species, $primer_data );

    #TODO: If no primer pairs pass the genomic check, need to call this method recursively with a different
    #set of parameters until two pairs of primers are found.

    return ($primer_data, $primer_passes);
}


sub pcr_genomic_check {
    my $well_id = shift;
    my $species = shift;
    my $primer_data = shift;


    # implement genomic specificity checking using BWA
    #

    my ($bwa_query_filespec, $work_dir ) = generate_pcr_bwa_query_file( $well_id, $primer_data );
    my $num_bwa_threads = 2;


    my $bwa = DesignCreate::Util::BWA->new(
            query_file        => $bwa_query_filespec,
            work_dir          => $work_dir,
            species           => $species,
            three_prime_check => 0,
            num_bwa_threads   => $num_bwa_threads,
    );

    $bwa->generate_sam_file;
    my $oligo_hits = $bwa->oligo_hits;
    $primer_data = filter_oligo_hits( $oligo_hits, $primer_data );

    return $primer_data;

}


sub genomic_check {
    my $design_id = shift;
    my $well_id = shift;
    my $species = shift;
    my $primer_data = shift;


    # implement genomic specificity checking using BWA
    #

    my ($bwa_query_filespec, $work_dir ) = generate_bwa_query_file( $design_id, $well_id, $primer_data );
    my $num_bwa_threads = 2;


    my $bwa = DesignCreate::Util::BWA->new(
            query_file        => $bwa_query_filespec,
            work_dir          => $work_dir,
            species           => $species,
            three_prime_check => 0,
            num_bwa_threads   => $num_bwa_threads,
    );

    $bwa->generate_sam_file;
    my $oligo_hits = $bwa->oligo_hits;
    $primer_data = filter_oligo_hits( $oligo_hits, $primer_data );

    return $primer_data;

}


sub filter_oligo_hits {
    my $hits_to_filter = shift;
    my $primer_data = shift;

    # select only the primers with highest rank
    # that are not hitting other areas of the genome

    # so that we only suggest max of two primer pairs.

    foreach my $key ( sort keys %{$primer_data->{'left'}} ) {
        $primer_data->{'left'}->{$key}->{'mapped'} = $hits_to_filter->{$key};
    }

    foreach my $key ( sort keys %{$primer_data->{'right'}} ) {
        $primer_data->{'right'}->{$key}->{'mapped'} = $hits_to_filter->{$key};
    }

    $primer_data = del_bad_pairs('left', $primer_data);
    $primer_data = del_bad_pairs('right', $primer_data);

    return $primer_data;
}

=head del_bad_pairs
Given: left | right, primer_data hashref
Returns: primer_data_hashref

     Process the input hash deleting any that do not have a unique_alignment key.
     Make sure there both a left and a right primer of the same rank.

=cut
sub del_bad_pairs {
    my $primer_end = shift;
    my $primer_data = shift;

    my $temp1;
    my $temp2;

    foreach my $primer ( sort keys %{$primer_data->{$primer_end}} ) {
        if ( ! defined $primer_data->{$primer_end}->{$primer}->{'mapped'}->{'unique_alignment'} ) {
            $primer =~ s/right/left/;
            my $left_primer = $primer;
            $primer =~ s/left/right/;
            my $right_primer = $primer;
            $temp1 = delete $primer_data->{'left'}->{$left_primer};
            $temp2 = delete $primer_data->{'right'}->{$right_primer};
        }
    }
    return $primer_data;
}

sub generate_pcr_bwa_query_file {
    my $well_id = shift;
    my $primer_data = shift;

    my $root_dir = $ENV{ 'LIMS2_BWA_OLIGO_DIR' } // '/var/tmp/bwa';
    use Data::UUID;
    my $ug = Data::UUID->new();

    my $unique_string = $ug->create_str();
    my $dir_out = dir( $root_dir, '_' . $well_id . $unique_string );
    mkdir $dir_out->stringify  or die 'Could not create directory ' . $dir_out->stringify . ": $!";

    my $fasta_file_name = $dir_out->file( $well_id . '_oligos.fasta');
    my $fh = $fasta_file_name->openw();
    my $seq_out = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );

    foreach my $oligo ( sort keys %{ $primer_data->{'left'} } ) {
        my $fasta_seq = Bio::Seq->new( -seq => $primer_data->{'left'}->{$oligo}->{'seq'}, -id => $oligo );
        $seq_out->write_seq( $fasta_seq );
    }

    foreach my $oligo ( sort keys %{ $primer_data->{'right'} } ) {
        my $fasta_seq = Bio::Seq->new( -seq => $primer_data->{'right'}->{$oligo}->{'seq'}, -id => $oligo );
        $seq_out->write_seq( $fasta_seq );
    }

    return ($fasta_file_name, $dir_out);
}



sub parse_primer3_results {
    my $result = shift;

    my $oligo_data;
    # iterate through each primer pair
    $oligo_data->{pair_count} = $result->num_primer_pairs;
    while (my $pair = $result->next_primer_pair) {
        # do stuff with primer pairs...
        my ($fp, $rp) = ($pair->forward_primer, $pair->reverse_primer);
        $oligo_data->{'left'}->{$fp->display_name} = parse_primer( $fp );
        $oligo_data->{'right'}->{$rp->display_name} = parse_primer( $rp );
    }

    return $oligo_data;
}

=head2 parse_primer


=cut
sub parse_primer {
    my $primer = shift;

    my %oligo_data;

    my @primer_attrs = qw/
        length
        melting_temp
        gc_content
        rank
        location
    /;


    %oligo_data = map { $_  => $primer->$_ } @primer_attrs;
    $oligo_data{'seq'} = $primer->seq->seq;

    return \%oligo_data;
}

sub primer_driver {
    my %params;

    $params{'schema'} = shift;
    $params{'design_id'} = shift;
    $params{'assembly'} = shift;

    my $design_oligos = oligos_for_gibson( \%params );

    return;
}

=head
Given crispr sequencing co-ordinates
Returns a sequence region
=cut

sub get_crispr_PCR_EnsEmbl_region{
    my $params = shift;

    my $schema = $params->{'schema'};
    my $crispr_primers = $params->{'crispr_primers'};
    my $species = $params->{'species'};
    my $repeat_mask = $params->{'repeat_mask'};

    my $slice_region;

    # Here we want a slice from the beginning of (start(left_0) - ($dead_width + $search_field))
    # to the end(right_0) + ($dead_width + $search_field)
    my $dead_field_width = 100;
    my $search_field_width = 500;


    my $chr_strand = $crispr_primers->{'strand'}; # That is the gene strand

    my $slice_adaptor = $registry->get_adaptor($species, 'Core', 'Slice');
    my $seq;


    my $start_target = $crispr_primers->{'crispr_primers'}->{'left'}->{'left_0'}->{'location'}->start
        + $crispr_primers->{'crispr_seq'}->{'chr_region_start'} ;
    my $end_target = $crispr_primers->{'crispr_primers'}->{'right'}->{'right_0'}->{'location'}->end
        + $crispr_primers->{'crispr_seq'}->{'chr_region_start'};

    my $start_coord =  $start_target - ($dead_field_width + $search_field_width);
    my $end_coord =  $end_target + ($dead_field_width + $search_field_width);
    $slice_region = $slice_adaptor->fetch_by_region(
        'chromosome',
        $crispr_primers->{'crispr_seq'}->{'left_crispr'}->{'chr_name'},
        $start_coord,
        $end_coord,
        $chr_strand eq 'plus' ? '1' : '-1' ,
    );
    if ( $chr_strand eq 'plus' ) {
        $seq = get_repeat_masked_sequence( {
                slice_region => $slice_region,
                repeat_mask => $repeat_mask,
                revcom  => 0,
            });
    }
    elsif ( $chr_strand eq 'minus' ) {
        $seq = get_repeat_masked_sequence( {
                slice_region => $slice_region,
                repeat_mask => $repeat_mask,
                revcom  => 0,
            });
    }

    my $target_sequence_length = ($end_target - $start_target) + 2 * $dead_field_width;
    my $target_sequence_string = $search_field_width . ',' . $target_sequence_length;


    return ( $seq, $target_sequence_string, $target_sequence_length );
}



sub pick_crispr_primers {
    my $params = shift;

    my $repeat_mask = $params->{'repeat_mask'};

    my $crispr_oligos = oligos_for_crispr_pair( $params->{'schema'}, $params->{'crispr_pair_id'} );

    # chr_strand for the gene is required because the crispr primers are named accordingly SF1, SR1
    my ( $region_bio_seq, $target_sequence_mask, $target_sequence_length, $chr_strand,
        $chr_seq_start, $chr_seq_end)
        = get_crispr_pair_EnsEmbl_region($params, $crispr_oligos, $repeat_mask );

    $crispr_oligos->{'chr_region_start'} = $chr_seq_start;

    my $p3 = DesignCreate::Util::Primer3->new_with_config(
        configfile => $ENV{ 'LIMS2_PRIMER3_CRISPR_SEQUENCING_PRIMER_CONFIG' },
        primer_product_size_range => $target_sequence_length . '-' . ($target_sequence_length + 500),
    );

    my $dir_out = dir( $ENV{ 'LIMS2_PRIMER_SELECTION_DIR' } );
    my $logfile = $dir_out->file( $params->{'crispr_pair_id'} . '_seq_oligos.log');

    my ( $result, $primer3_explain ) = $p3->run_primer3( $logfile->absolute, $region_bio_seq, # bio::seqI
            { SEQUENCE_TARGET => $target_sequence_mask ,
            } );
    # for sequencing dont want pairs
    my %failed_primer_regions;
    if ( $result->num_primer_pairs ) {
        INFO ( $params->{'crispr_pair_id'} . ' sequencing primers : ' . $result->num_primer_pairs );
    }
    else {
        INFO ( 'Failed to generate sequencing primers for ' . $params->{'crispr_pair_id'} );
        $failed_primer_regions{$params->{'crispr_pair_id'}} = $primer3_explain;

    }

    my $primer_data = parse_primer3_results( $result );
    #
    use DesignCreate::Exception::Primer3FailedFindOligos;

    if (%failed_primer_regions) {
        DesignCreate::Exception::Primer3FailedFindOligos->throw(
            regions             => [ keys %failed_primer_regions ],
            primer_fail_reasons => \%failed_primer_regions,
        );
    }

    return ($crispr_oligos, $primer_data, $chr_strand);
}

=head2 oligos_for_crispr_pair

Generate sequencing primer oligos for a crispr pair

These oligos should be 100b from the 5' end of the left crispr so that sequencing reads into the crispr itself.

For the right crispr, the primer should be 100b from the 3' end of the crispr, again so that sequencing
reads into the crispr itself

Given crispr pair id
Returns Hash of two oligos forming the left and right crispr pair.

=cut

sub oligos_for_crispr_pair {
    my $schema = shift;
    my $crispr_pair_id = shift;


    my $crispr_pairs_rs = crispr_pair_oligos_rs( $schema, $crispr_pair_id );
    my $crispr_pair = $crispr_pairs_rs->first;

    my %crispr_pairs;
    $crispr_pairs{'left_crispr'}->{'id'} = $crispr_pair->left_crispr_locus->crispr_id;
    $crispr_pairs{'left_crispr'}->{'chr_start'} = $crispr_pair->left_crispr_locus->chr_start;
    $crispr_pairs{'left_crispr'}->{'chr_end'} = $crispr_pair->left_crispr_locus->chr_end;
    $crispr_pairs{'left_crispr'}->{'chr_strand'} = $crispr_pair->left_crispr_locus->chr_strand;
    $crispr_pairs{'left_crispr'}->{'chr_id'} = $crispr_pair->left_crispr_locus->chr_id;
    $crispr_pairs{'left_crispr'}->{'chr_name'} = $crispr_pair->left_crispr_locus->chr->name;
    $crispr_pairs{'left_crispr'}->{'seq'} = $crispr_pair->left_crispr_locus->crispr->seq;

    $crispr_pairs{'right_crispr'}->{'id'} = $crispr_pair->right_crispr_locus->crispr_id;
    $crispr_pairs{'right_crispr'}->{'chr_start'} = $crispr_pair->right_crispr_locus->chr_start;
    $crispr_pairs{'right_crispr'}->{'chr_end'} = $crispr_pair->right_crispr_locus->chr_end;
    $crispr_pairs{'right_crispr'}->{'chr_strand'} = $crispr_pair->right_crispr_locus->chr_strand;
    $crispr_pairs{'right_crispr'}->{'chr_id'} = $crispr_pair->right_crispr_locus->chr_id;
    $crispr_pairs{'right_crispr'}->{'chr_name'} = $crispr_pair->right_crispr_locus->chr->name;
    $crispr_pairs{'right_crispr'}->{'seq'} = $crispr_pair->right_crispr_locus->crispr->seq;

    return \%crispr_pairs;
}

sub crispr_pair_oligos_rs {
    my $schema = shift;
    my $crispr_pair_id = shift;

    my $crispr_rs = $schema->resultset('CrisprPair')->search(
        {
            'id' => $crispr_pair_id,
        },
    );

    return $crispr_rs;
}


=head get_crispr_pair_EnsEmbl_region

We calculate crisprs left and right on the same strand as the gene.
Thus we need the gene's strand to get the correct sequence region.
We don't use the crispr strand information.

[SF1] >100bp [Left_Crispr] --- [Right_Crispr] > 100bp [SR1]

SF and SR with repsect to the sense of the gene (not the sense of EnsEmbl)
=cut

sub get_crispr_pair_EnsEmbl_region {
    my $params = shift;
    my $crispr_oligos = shift;

    my $design_r = $params->{'schema'}->resultset('Design')->find($params->{'design_id'});
    my $design_info = LIMS2::Model::Util::DesignInfo->new( design => $design_r );
    my $design_oligos = $design_info->oligos;
    my $repeat_mask = $params->{'repeat_mask'};

    my $chr_strand = $design_info->chr_strand eq '1' ? 'plus' : 'minus';

    my $slice_region;
    my $seq;
    my $crispr_length = length($crispr_oligos->{'left_crispr'}->{'seq'});
    # dead field width is the number of bases in which primers must not be found.
    # This is because sequencing oligos needs some run-in to the region of interest.
    # So, we need a region that covers from the 3' end of the crispr back to (len_crispr + dead_field + live_field)
    # 5' (live_field + dead_field + len_crispr)
    my $dead_field_width = 100;
    my $search_field_width = 200;

    my $start_coord = $crispr_oligos->{'left_crispr'}->{'chr_start'};
    my $region_start_coord = $start_coord - ($dead_field_width + $search_field_width);
    my $end_coord = $crispr_oligos->{'right_crispr'}->{'chr_end'};
    my $region_end_coord = $end_coord + ($dead_field_width + $search_field_width );

    my $slice_adaptor = $registry->get_adaptor($params->{'species'}, 'Core', 'Slice');
    if ( $chr_strand eq 'plus' ) {
        $slice_region = $slice_adaptor->fetch_by_region(
            'chromosome',
            $crispr_oligos->{'left_crispr'}->{'chr_name'},
            $region_start_coord,
            $region_end_coord,
            1,

        );
        $seq = get_repeat_masked_sequence( {
                slice_region => $slice_region,
                repeat_mask => $repeat_mask,
                revcom  => 0,
            });
    }
    elsif ( $chr_strand eq 'minus' ) {
        $slice_region = $slice_adaptor->fetch_by_region(
            'chromosome',
            $crispr_oligos->{'left_crispr'}->{'chr_name'},
            $region_start_coord,
            $region_end_coord,
            -1,
        );
        $seq = get_repeat_masked_sequence( {
                slice_region => $slice_region,
                repeat_mask => $repeat_mask,
                revcom  => 1,
            });
    }

    my $target_sequence_length = ($end_coord - $start_coord) + 2 * $dead_field_width;
    # target sequence is <start, length> and in this case indicates the region we want to sequence

    my $target_sequence_string =  $search_field_width . ',' . $target_sequence_length;

    my $chr_seq_start = $slice_region->start;
    my $chr_seq_end = $slice_region->end;
    return ($seq, $target_sequence_string, $target_sequence_length, $chr_strand,
            $chr_seq_start, $chr_seq_end)  ;
}


=head get_crispr_EnsEmbl_region
Debugging and development only

An approach for a single crispr sequencing but probably should use the paired crispr approach
in get_crispr_pair_EnsEmbl_region
=cut

sub get_crispr_EnsEmbl_region {
    my $crispr_oligos = shift;
    my $side = shift;
    my $species = shift;


    my $chr_strand = $crispr_oligos->{$side}->{'chr_strand'} eq '1' ? 'plus' : 'minus';
    my $slice_region;
    my $seq;
    my $crispr_length = length($crispr_oligos->{$side}->{'seq'});
    # dead field width is the number of bases in which primers must not be found.
    # This is because sequencing oligos nees some run-in to the region of interest.
    # So, we need a region that covers from the 3' end of the crispr back to (len_crispr + dead_field + live_field)
    # 5' (live_field + dead_field + len_crispr)
    my $dead_field_width = 100;
    my $live_field_width = 200;

    my $slice_adaptor = $registry->get_adaptor($species, 'Core', 'Slice');
    if ( $chr_strand eq 'plus' ) {
        $slice_region = $slice_adaptor->fetch_by_region(
            'chromosome',
            $crispr_oligos->{$side}->{'chr_name'},
            $crispr_oligos->{$side}->{'chr_start'} - $dead_field_width - $live_field_width,
            $crispr_oligos->{$side}->{'chr_end'},
            $crispr_oligos->{$side}->{'chr_strand'},

        );
        $seq = Bio::Seq->new( -alphabet => 'dna', -seq => $slice_region->seq, -verbose => -1 );
    }
    elsif ( $chr_strand eq 'minus' ) {
        $slice_region = $slice_adaptor->fetch_by_region(
            'chromosome',
            $crispr_oligos->{$side}->{'chr_name'},
            $crispr_oligos->{$side}->{'chr_start'} - $dead_field_width - $live_field_width,
            $crispr_oligos->{$side}->{'chr_end'},
            $crispr_oligos->{$side}->{'chr_strand'},
        );
        # $seq = Bio::Seq->new( -alphabet => 'dna', -seq => $slice_region->seq, -verbose => -1 )->revcom;
        $seq = Bio::Seq->new( -alphabet => 'dna', -seq => $slice_region->seq, -verbose => -1 );
    }

    my $target_sequence_length = $seq->length - ($dead_field_width + $crispr_length);
    # target sequence is <start, length> and in this case indicates the region we want to sequence
    my $target_sequence_string = '1' . ',' . $target_sequence_length;

    my $chr_seq_start = $slice_region->start;
    my $chr_seq_end = $slice_region->end;
    return ($seq, $target_sequence_string, $target_sequence_length, $chr_seq_start, $chr_seq_end) ;
}


sub get_repeat_masked_sequence {
    my $params = shift;

    my $slice_region = $params->{'slice_region'};
    my $repeat_mask = $params->{'repeat_mask'};
    my $revcom = $params->{'revcom'};
    my $seq;
    if ( $repeat_mask->[0] eq 'NONE' ) {
        DEBUG('No repeat masking selected');
        $seq = Bio::Seq->new( -alphabet => 'dna', -seq => $slice_region->seq, -verbose => -1 );
    }
    else {
        DEBUG('Repeat masking selected');
        $seq = Bio::Seq->new( -alphabet => 'dna', -seq => $slice_region->get_repeatmasked_seq($repeat_mask)->seq, -verbose => -1 );
    }
    if ( $revcom ) {
        $seq = $seq->revcom;
    }
    return $seq;
}

1;
