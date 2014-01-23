package WGE::Util::CreateDesign;

use Moose;
use WebAppCommon::Util::EnsEMBL;
use Const::Fast;
use Path::Class;
use namespace::autoclean;

use warnings FATAL => 'all';


const my $DEFAULT_DESIGNS_DIR =>  $ENV{ DEFAULT_DESIGNS_DIR } //
                                    '/lustre/scratch109/sanger/team87/wge_designs';

has model => (
    is       => 'ro',
    isa      => 'WGE::Model::DB',
    required => 1,
    handles  => {
        check_params          => 'check_params',
        create_design_attempt => 'create_design_attempt',
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
    lazy_build => 1,
);

sub _build_species {
    my $self = shift;

    # FIXME
    return "Human";
    #return $self->catalyst->session->{selected_species};
}

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

    # FIXME
    return "dummy";
    #return $self->catalyst->user->name;
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

    # FIXME
    return "fixme";
    #return $DEFAULT_SPECIES_BUILD{ lc($self->species) };
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
    $self->designs_for_exons( $exon_data, $gene_data->{gene_id} );

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


=head2 create_gibson_design

Wrapper for all the seperate subroutines we need to run to
initiate the creation of a gibson design

=cut
sub create_gibson_design {
    my ( $self ) = @_;

    
    my $params         = $self->c_parse_and_validate_gibson_params();
    my $design_attempt = $self->c_initiate_design_attempt( $params );
    my $cmd            = $self->c_generate_gibson_design_cmd( $params );
    my $job_id         = $self->c_run_design_create_cmd( $cmd, $params );

    return $design_attempt;
}


__PACKAGE__->meta->make_immutable;

1;

__END__