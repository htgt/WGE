package WGE::Util::CreateDesign;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::CreateDesign::VERSION = '0.067';
}
## use critic


use Moose;
use WebAppCommon::Util::EnsEMBL;
use WGE::Exception::Validation;
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
    my $user = $self->catalyst->user->name || "guest";
    return $user;
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

    return ( $gene_data, $exon_data );
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

=head2 throw_validation_error

Override parent throw method to use WGE::Exception::Validation.

=cut
around 'throw_validation_error' => sub {
    my $orig = shift;
    my $self = shift;
    my $errors = shift;

    WGE::Exception::Validation->throw(
        message => $errors,
    );
};

__PACKAGE__->meta->make_immutable;

1;

__END__
