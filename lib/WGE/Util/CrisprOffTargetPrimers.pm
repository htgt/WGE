package WGE::Util::CrisprOffTargetPrimers;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::CrisprOffTargetPrimers::VERSION = '0.064';
}
## use critic


=head1 NAME

WGE::Util::CrisprOffTargetPrimers

=head1 DESCRIPTION

Generate pcr and sequencing primers for selected crispr off target sites.

=cut

use Moose;

use HTGT::QC::Util::GeneratePrimersAttempts;
use LIMS2::REST::Client;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsDir AbsFile/;
use Try::Tiny;
use Path::Class;
use Const::Fast;
use YAML::Any qw( LoadFile DumpFile );
use Hash::MoreUtils qw( slice_def );
use Bio::Perl qw( revcom_as_string );

use namespace::autoclean;

with 'MooseX::Log::Log4perl';

my %PRIMER_PROJECT_CONFIG_FILES = (
    crispr_off_target_sequencing_primers => $ENV{CRISPR_OFF_TARGETS_SEQUENCING_PRIMER_CONFIG}
            || '/nfs/team87/farm3_lims2_vms/conf/primers/wge_crispr_off_target_sequencing.yaml',
    crispr_off_target_pcr_primers => $ENV{CRISPR_OFF_TARGETS_PCR_PRIMER_CONFIG}
            || '/nfs/team87/farm3_lims2_vms/conf/primers/wge_crispr_off_target_pcr.yaml',
);

has max_off_target_mismatches => (
    is      => 'ro',
    isa     => 'Int',
    default => 3,
);

has persist_crisprs_lims2 => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has lims2_api => (
    is         => 'ro',
    isa        => 'LIMS2::REST::Client',
    lazy_build => 1
);

sub _build_lims2_api {
    return LIMS2::REST::Client->new_with_config();
}

has pcr_primer_config => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
);

sub _build_pcr_primer_config {
    my $self = shift;
    return LoadFile( $PRIMER_PROJECT_CONFIG_FILES{crispr_off_target_pcr_primers} );
}

has sequencing_primer_config => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
);

sub _build_sequencing_primer_config {
    my $self = shift;
    return LoadFile( $PRIMER_PROJECT_CONFIG_FILES{crispr_off_target_sequencing_primers} );
}

has pcr_primer3_config_file => (
    is         => 'ro',
    isa        => AbsFile,
    lazy_build => 1,
);

sub _build_pcr_primer3_config_file {
    my $self = shift;

    if ( my $file_name = $self->pcr_primer_config->{primer3_config} ) {
        return file( $file_name )->absolute;
    }
    else {
        die 'No primer3_config value in primer project config file '
            . $PRIMER_PROJECT_CONFIG_FILES{crispr_off_target_pcr_primers};
    }

    return;
}

has sequencing_primer3_config_file => (
    is         => 'ro',
    isa        => AbsFile,
    lazy_build => 1,
);

sub _build_sequencing_primer3_config_file {
    my $self = shift;

    if ( my $file_name = $self->sequencing_primer_config->{primer3_config} ) {
        return file( $file_name )->absolute;
    }
    else {
        die 'No primer3_config value in primer project config file '
            . $PRIMER_PROJECT_CONFIG_FILES{crispr_off_target_sequencing_primers};
    }

    return;
}

has base_dir => (
    is       => 'ro',
    isa      => AbsDir,
    required => 1,
    coerce   => 1,
);

=head2 crispr_off_targets_primers

Generate pcr and sequencing primers for all selected off target
sites for given crispr.

=cut
sub crispr_off_targets_primers {
    my ( $self, $crispr ) = @_;
    $self->log->info( "GENERATE OFF TARGET PRIMERS for crispr " . $crispr->id );

    my $crispr_dir = $self->base_dir->subdir( 'crispr_' . $crispr->id )->absolute;
    $crispr_dir->mkpath;
    my ( $species, $assembly ) = $self->get_crispr_species_and_assembly( $crispr );
    my $lims2_crispr = $self->find_or_create_lims2_crispr( $crispr, $species, $assembly );

    # get crispr grna sequence in standard orientation
    my $fwd_seq = $crispr->pam_right ? $crispr->seq : revcom_as_string( $crispr->seq );
    my $crispr_grna = substr $fwd_seq, 0, 20;

    my ( @off_target_primers, %summary );
    for my $off_target ( $crispr->off_targets->all ) {
        Log::Log4perl::NDC->remove;
        Log::Log4perl::NDC->push( $crispr->id );
        Log::Log4perl::NDC->push( $off_target->id );
        # skip off target record for original crispr
        next if $off_target->id == $crispr->id;

        # filter out off targets with more that 3 mismatches
        my $mismatches = $off_target->mismatches( $crispr_grna );
        next if $mismatches > $self->max_off_target_mismatches;

        my $primer_data = $self->off_target_primers( $lims2_crispr, $off_target, \%summary, $mismatches, $species, $assembly, $crispr_dir );
        push @off_target_primers, $primer_data;
    }

    return ( \@off_target_primers, \%summary );
}

=head2 off_target_primers

Attempt to generate primers for off target

=cut
sub off_target_primers {
    my ( $self, $lims2_crispr, $off_target, $summary, $mismatches, $species, $assembly, $crispr_dir ) = @_;

    $summary->{$off_target->id}{mismatches} = $mismatches;
    $summary->{$off_target->id}{exonic}     = $off_target->exonic;
    $summary->{$off_target->id}{genic}      = $off_target->genic;

    # check it ot crispr exists in LIMS2 and export if it does not
    my $lims2_ot_crispr = $self->find_or_create_lims2_crispr( $off_target, $species, $assembly );
    $summary->{$off_target->id}{lims2_crispr_id} = $lims2_ot_crispr->{id} if $lims2_ot_crispr;
    my $lims2_ot = $self->create_lims2_crispr_off_target( $lims2_crispr, $lims2_ot_crispr, $mismatches );

    my $dir = $crispr_dir->subdir( $off_target->id );
    $dir->mkpath;

    my %data = (
        ot         => $off_target,
        mismatches => $mismatches,
        species    => $species,
    );
    $data{lims2_ot} = $lims2_ot if $lims2_ot;

    my ( $seq_primers, $pcr_primers );
    if ( $seq_primers = $self->generate_sequencing_primers( $off_target, $dir, $species  ) ) {
        $data{sequencing} = $seq_primers;
        if ( $pcr_primers = $self->generate_pcr_primers( $off_target, $seq_primers, $dir, $species ) ) {
            $data{pcr} = $pcr_primers;
            $summary->{$off_target->id}{status} = 'both';
        }
        else {
            $summary->{$off_target->id}{status} = 'seq_only';
        }
    }
    else {
        if ( $pcr_primers = $self->generate_pcr_primers( $off_target, undef, $dir, $species ) ) {
            $data{pcr} = $pcr_primers;
            $summary->{$off_target->id}{status} = 'pcr_only';
        }
        else {
            $summary->{$off_target->id}{status} = 'fail';
        }
    }

    return \%data;
}

=head2 get_crispr_species_name

Work out species of crispr.

=cut
sub get_crispr_species_and_assembly {
    my ( $self, $crispr ) = @_;

    my ( $species, $assembly );
    if ( $crispr->species->id eq 'Grch38' ) {
        $species = 'Human';
        $assembly = 'GRCh38';
    }
    elsif ( $crispr->species->id eq 'Mouse' ) {
        $species = 'Mouse';
        $assembly = 'GRCm38';
    }
    else {
        die( 'Can only work with Human or Mouse crisprs on current assembly, not: '
                . $crispr->species->display_name );
    }

    return ( $species, $assembly );
}

=head2 generate_sequencing_primers

Generate the sequencing primers for the crispr off target, used to show the sequence
around the crispr site and show any potential damage.
These primers are run against the PCR product, which is created using the pcr_primers
created here.
As the primers are run against the pcr product no genomic specificity check is needed.

=cut
sub generate_sequencing_primers {
    my ( $self, $off_target, $dir, $species ) = @_;

    my $work_dir = $dir->subdir( 'sequencing_primers' );
    $work_dir->mkpath;

    $self->log->info( 'Searching for sequencing primers'  );
    my $sequencing_primer_finder = HTGT::QC::Util::GeneratePrimersAttempts->new(
        base_dir            => $work_dir,
        species             => $species,
        strand              => 1, # always global +ve strand
        chromosome          => $off_target->chr_name,
        target_start        => $off_target->chr_start,
        target_end          => $off_target->chr_end,
        primer3_config_file => $self->sequencing_primer3_config_file,
        slice_def(
            $self->sequencing_primer_config,
            qw( five_prime_region_size five_prime_region_offset
                three_prime_region_size three_prime_region_offset
                primer_search_region_expand check_genomic_specificity
                retry_attempts
                )
        )
    );

    my ( $seq_primer_data, $seq ) = $sequencing_primer_finder->find_primers;

    unless ( $seq_primer_data ) {
        $self->log->error( 'FAIL: Unable to generate sequencing primers' );
        return;
    }

    $self->log->info( 'SUCCESS: Found sequencing primers for target' );
    DumpFile( $work_dir->file('sequencing_primers.yaml'), $seq_primer_data );

    return $seq_primer_data->[0];
}

=head2 generate_pcr_primers

Generate the pcr primers for the crispr off target, used to amplify the region
around the off target site for further analysis.
The primers are run against the whole genome, so we must carry out genomic
specificity checks against the primers.

=cut
sub generate_pcr_primers {
    my ( $self, $off_target, $seq_primers, $dir, $species ) = @_;

    my $work_dir = $dir->subdir( 'pcr_primers' );
    $work_dir->mkpath;
    my ( $target_start, $target_end );
    if ( $seq_primers ) {
        $target_start = $seq_primers->{forward}{oligo_start};
        $target_end   = $seq_primers->{reverse}{oligo_end};
    }
    else {
        $target_start = $off_target->chr_start - 300;
        $target_end   = $off_target->chr_end + 300;
    }

    $self->log->info( 'Searching for pcr primers' );
    my $pcr_primer_finder = HTGT::QC::Util::GeneratePrimersAttempts->new(
        base_dir            => $work_dir,
        species             => $species,
        strand              => 1, # always global +ve strand
        chromosome          => $off_target->chr_name,
        target_start        => $target_start,
        target_end          => $target_end,
        primer3_config_file => $self->pcr_primer3_config_file,
        slice_def(
            $self->pcr_primer_config,
            qw( five_prime_region_size five_prime_region_offset
                three_prime_region_size three_prime_region_offset
                primer_search_region_expand check_genomic_specificity
                retry_attempts
                )
        )
    );

    my ( $pcr_primer_data, $seq ) = $pcr_primer_finder->find_primers;

    unless ( $pcr_primer_data ) {
        $self->log->error( 'FAIL: Unable to generate pcr primers' );
        return;
    }

    $self->log->info( 'SUCCESS: Found pcr primers' );
    DumpFile( $work_dir->file('pcr_primers.yaml'), $pcr_primer_data );

    return $pcr_primer_data->[0];
}

=head2 find_or_create_lims2_crispr

Find of create a crispr in LIMS2, through the REST API.

=cut
sub find_or_create_lims2_crispr {
    my ( $self, $crispr, $species, $assembly ) = @_;
    return unless $self->persist_crisprs_lims2;

    # check if it exists in LIMS2, if it does then do nothing
    my $lims2_crispr = try{ $self->lims2_api->GET( 'single_crispr', { wge_crispr_id => $crispr->id } ) };
    if ( $lims2_crispr ) {
        $self->log->debug( 'Crispr exists in LIMS2' );
        return $lims2_crispr;
    }
    my $type = $crispr->exonic ? 'Exonic' : $crispr->genic ? 'Intergenic' : 'Intronic';

    my $wge_crispr = $crispr->as_hash;
    my $lims2_crispr_data = {
        species              => $species,
        off_target_algorithm => 'wge',
        type                 => $type,
        wge_crispr_id        => $wge_crispr->{id},
        locus                => {
            chr_name   => $wge_crispr->{chr_name},
            chr_start  => $wge_crispr->{chr_start},
            chr_end    => $wge_crispr->{chr_end},
            chr_strand => $wge_crispr->{pam_right} ? 1 : -1,
            assembly   => $assembly,
        },
        pam_right => $wge_crispr->{pam_right},
        seq       => $wge_crispr->{seq},
        off_target_summary => $wge_crispr->{off_target_summary},
    };

    $lims2_crispr = $self->lims2_api->POST( 'single_crispr', $lims2_crispr_data );

    return $lims2_crispr;
}

=head2 create_lims2_crispr_off_target

Create a off target link between two crisprs in LIMS2.

=cut
sub create_lims2_crispr_off_target {
    my ( $self, $lims2_crispr, $lims2_ot_crispr, $mismatches ) = @_;
    return unless $self->persist_crisprs_lims2;

    my $ot_data = {
        crispr_id    => $lims2_crispr->{id},
        ot_crispr_id => $lims2_ot_crispr->{id},
        mismatches   => $mismatches,
    };

    # check if off target already exists in LIMS2
    my $lims2_ot;
    $lims2_ot = try {
        $self->lims2_api->GET( 'crispr_off_target',
            { crispr_id => $lims2_crispr->{id}, off_target_crispr_id => $lims2_ot_crispr->{id} } );
    };

    unless ( $lims2_ot ) {
        $lims2_ot = $self->lims2_api->POST( 'crispr_off_target', $ot_data );
    }

    return $lims2_ot;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
