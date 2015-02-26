package WGE::Util::CrisprOffTargetPrimers;

=head1 NAME

WGE::Util::CrisprOffTargetPrimers

=head1 DESCRIPTION

Generate pcr and sequencing primers for crispr off targets.

=cut

use Moose;

use HTGT::QC::Util::GeneratePrimersAttempts;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsDir AbsFile/;
use Try::Tiny;
use Path::Class;
use Const::Fast;
use YAML::Any qw( LoadFile DumpFile );
use Hash::MoreUtils qw( slice_def );

use Smart::Comments;

use namespace::autoclean;

with 'MooseX::Log::Log4perl';

my %PRIMER_PROJECT_CONFIG_FILES = (
    crispr_off_target_sequencing_primers => $ENV{CRISPR_OFF_TARGETS_SEQUENCING_PRIMER_CONFIG}
            || '/nfs/users/nfs_s/sp12/workspace/WGE/tmp/wge_crispr_off_target_sequencing.yaml',
            #|| '/opt/t87/global/conf/primers/wge_crispr_off_target_sequencing.yaml',
    crispr_off_target_pcr_primers => $ENV{CRISPR_OFF_TARGETS_PCR_PRIMER_CONFIG}
            || '/nfs/users/nfs_s/sp12/workspace/WGE/tmp/wge_crispr_off_target_pcr.yaml',
            #|| '/opt/t87/global/conf/primers/wge_crispr_off_target_genotyping.yaml',
);

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

# PCR Primers
# need genomic specificity checks
# produce primers that produce PCR product

# Sequencing Primers
# Run against the PCR product, show sequence around crispr site
# no need for genomic specificity check

=head2 crispr_off_targets_primers

=cut
sub crispr_off_targets_primers {
    my ( $self, $crispr ) = @_;
    $self->log->info( "GENERATE OFF TARGET PRIMERS for crispr " . $crispr->id );

    my $crispr_dir = $self->base_dir->subdir( 'crispr_' . $crispr->id )->absolute;
    $crispr_dir->mkpath;

    my $species = $self->get_crispr_species_name( $crispr );
    my $fwd_seq = $crispr->pam_right ? $crispr->seq : revcom_as_string( $crispr->seq );
    my $crispr_grna = substr $fwd_seq, 0, 20;

    my @off_target_primers;
    for my $off_target ( $crispr->off_targets->all ) {
        Log::Log4perl::NDC->remove;
        Log::Log4perl::NDC->push( $off_target->id );
        # skip off target record for original crispr
        next if $off_target->id == $crispr->id;

        # filter out off targets with more that 3 mismatches
        my $mismatches = $off_target->mismatches( $crispr_grna );
        next if $mismatches > 3;

        my $off_target_dir = $crispr_dir->subdir( $off_target->id );
        $off_target_dir->mkpath;

        my $sequencing_primers = $self->sequencing_primers( $off_target, $off_target_dir, $species );
        next unless $sequencing_primers;
        my $pcr_primers = $self->pcr_primers( $off_target, $sequencing_primers, $off_target_dir, $species );

        push @off_target_primers, {
            ot                 => $off_target,
            mismatches         => $mismatches,
            sequencing_primers => $sequencing_primers,
            pcr_primers        => $pcr_primers,
        };
        last;
    }

    return \@off_target_primers;
}

=head2 get_crispr_species_name

desc

=cut
sub get_crispr_species_name {
    my ( $self, $crispr ) = @_;

    my $species;
    if ( $crispr->species->id eq 'Grch38' ) {
        $species = 'Human';
    }
    elsif ( $crispr->species->id eq 'Mouse' ) {
        $species = 'Mouse';
    }
    else {
        die( 'Can only work with Human or Mouse crisprs on current assembly, not: '
                . $crispr->species->display_name );
    }

    return $species;
}

=head2 sequencing_primers

desc

=cut
sub sequencing_primers {
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

=head2 pcr_primers

desc

=cut
sub pcr_primers {
    my ( $self, $off_target, $sequencing_primers, $dir, $species ) = @_;

    my $work_dir = $dir->subdir( 'pcr_primers' );
    $work_dir->mkpath;

    $self->log->info( 'Searching for pcr primers' );
    my $pcr_primer_finder = HTGT::QC::Util::GeneratePrimersAttempts->new(
        base_dir            => $work_dir,
        species             => $species,
        strand              => 1, # always global +ve strand
        chromosome          => $off_target->chr_name,
        target_start        => $sequencing_primers->{forward}{oligo_start},
        target_end          => $sequencing_primers->{reverse}{oligo_end},
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

__PACKAGE__->meta->make_immutable;

1;

__END__
