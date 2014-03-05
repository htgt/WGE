package WGE::Util::CreateDesign;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::CreateDesign::VERSION = '0.004';
}
## use critic


use Moose;
use WebAppCommon::Util::EnsEMBL;
use Const::Fast;
use Path::Class;
use namespace::autoclean;

use warnings FATAL => 'all';

const my $DEFAULT_DESIGNS_DIR => $ENV{DEFAULT_DESIGNS_DIR} //
                                    '/lustre/scratch109/sanger/team87/wge_designs';

has model => (
    is       => 'ro',
    isa      => 'WGE::Model::DB',
    required => 1,
    handles  => {
        check_params            => 'check_params',
        create_design_attempt   => 'c_create_design_attempt',
        c_create_design_attempt => 'c_create_design_attempt',
    }
);

has catalyst => (
    is       => 'ro',
    isa      => 'Catalyst',
    required => 1,
);

has species => (
    is         => 'ro',
    isa        => 'Str',
    required   => 1,
);

has ensembl_util => (
    is         => 'ro',
    isa        => 'WebAppCommon::Util::EnsEMBL',
    lazy_build => 1,
);

sub _build_ensembl_util {
    my $self = shift;

    return WebAppCommon::Util::EnsEMBL->new( species => $self->species );
}

has user => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_user {
    my $self = shift;

    # We will add user login later
    return "guest";
}

has assembly_id => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_assembly_id {
    my $self = shift;

    return $self->model->schema->resultset('SpeciesDefaultAssembly')
        ->find( { species_id => $self->species } )->assembly_id;
}

has build_id => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_build_id {
    my $self = shift;

    # Should we get this from LIMS2 Contants.pm?
    my %default_build = (
            Human => 73,
            Mouse => 73,
        );

    return $default_build{ $self->species };
}

has base_design_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

sub _build_base_design_dir {
    return dir( $DEFAULT_DESIGNS_DIR );
}

with qw(
MooseX::Log::Log4perl
WebAppCommon::Design::CreateInterface
);

=head2 exons_for_gene

Given a gene name find all its exons that could be targeted for a design.
Optionally get all exons or just exons from canonical transcript.

=cut
sub exons_for_gene {
    my ( $self, $gene_name, $exon_types ) = @_;

    my $gene = $self->ensembl_util->get_ensembl_gene( $gene_name );
    return unless $gene;

    my $gene_data = $self->c_build_gene_data( $gene );

    my $exon_data = $self->c_build_gene_exon_data( $gene, $gene_data->{gene_id}, $exon_types );
    
    # Do we want to do this in WGE??
    #$self->designs_for_exons( $exon_data, $gene_data->{gene_id} );

    return ( $gene_data, $exon_data );
}

=head2 designs_for_exons

Grab any existing designs for the exons.

=cut
sub designs_for_exons {
    my ( $self, $exons, $gene_id ) = @_;

    $self->log->debug("Getting designs for gene $gene_id");

    my @gene_designs = $self->model->schema->resultset('GeneDesign')->search(
         { gene_id => $gene_id }
    );

    my @designs = map { $_->design } @gene_designs;

    my $assembly = $self->model->schema->resultset('SpeciesDefaultAssembly')->find(
        { species_id => $self->species } )->assembly_id;

    for my $exon ( @{ $exons } ) {
        my @matching_designs;

        for my $design ( @designs ) {

            my $oligo_data = prebuild_oligos( $design, $assembly );
            # if no oligo data then design does not have oligos on assembly
            # FIXME -  don't use LIMS2::Model
            next unless $oligo_data;
            my $di = LIMS2::Model::Util::DesignInfo->new(
                design => $design,
                oligos => $oligo_data,
            );
            if ( $exon->{start} > $di->target_region_start
                && $exon->{end} < $di->target_region_end
                && $exon->{chr} eq $di->chr_name
            ) {
                push @matching_designs, $design;
            }
        }
        $exon->{designs} = [ map { $_->id } @matching_designs ]
            if @matching_designs;
    }
    return;
}

=head2 target_params_from_exons

Given target exons return target coordinates

=cut
sub target_params_from_exons {
    my ( $self ) = @_;

    return $self->c_target_params_from_exons();
}

=head2 create_exon_target_gibson_design

Wrapper for all the seperate subroutines we need to run to
initiate the creation of a gibson design with a exon target.

=cut
sub create_exon_target_gibson_design {
    my ( $self ) = @_;

    my $params         = $self->c_parse_and_validate_exon_target_gibson_params();
    my $design_attempt = $self->c_initiate_design_attempt( $params );
    my $cmd            = $self->c_generate_gibson_design_cmd( $params );
    my $job_id         = $self->c_run_design_create_cmd( $cmd, $params );

    return ( $design_attempt, $job_id );
}

=head2 create_custom_target_gibson_design

Wrapper for all the seperate subroutines we need to run to
initiate the creation of a gibson design with a custom target.

=cut
sub create_custom_target_gibson_design {
    my ( $self ) = @_;

    my $params         = $self->c_parse_and_validate_custom_target_gibson_params();
    my $design_attempt = $self->c_initiate_design_attempt( $params );
    my $cmd            = $self->c_generate_gibson_design_cmd( $params );
    my $job_id         = $self->c_run_design_create_cmd( $cmd, $params );

    return ( $design_attempt, $job_id );
}

=head2 prebuild_oligos

Copied from LIMS2::Model::Util::DesignTargets
Pre-build oligo hash for design from pre-fetched data to feed into design info object.
This stops the design info object making its own database queries and speeds up the
overall data retrieval.

=cut
sub prebuild_oligos {
    my ( $design, $default_assembly ) = @_;

    my %design_oligos_data;
    for my $oligo ( $design->oligos ) {
        my ( $locus ) = grep{ $_->assembly_id eq $default_assembly } $oligo->loci;
        return unless $locus;

        my %oligo_data = (
            start      => $locus->chr_start,
            end        => $locus->chr_end,
            chromosome => $locus->chr->name,
            strand     => $locus->chr_strand,
        );
        $oligo_data{seq} = $oligo->seq;

        $design_oligos_data{ $oligo->design_oligo_type_id } = \%oligo_data;
    }

    return \%design_oligos_data;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
