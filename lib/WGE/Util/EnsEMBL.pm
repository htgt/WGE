package WGE::Util::EnsEMBL;

#stolen straight from LIMS2-Utils so we don't have a dependency.

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::ClassAttribute;
use Bio::EnsEMBL::Registry;
use namespace::autoclean;

# registry is a class variable to ensure that load_registry_from_db() is
# called only once

class_has registry => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1
);

sub _build_registry {

    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host => $ENV{LIMS2_ENSEMBL_HOST} || 'ensembldb.internal.sanger.ac.uk',
        -user => $ENV{LIMS2_ENSEMBL_USER} || 'anonymous'
    );

    return 'Bio::EnsEMBL::Registry';
}

has species => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

sub db_adaptor {
    my ( $self, $species ) = @_;
    return $self->registry->get_DBAdaptor( $species || $self->species, 'core' );
}

sub gene_adaptor {
    my ( $self, $species ) = @_;
    return $self->registry->get_adaptor( $species || $self->species, 'core', 'gene' );
}

sub slice_adaptor {
    my ( $self, $species ) = @_;
    return $self->registry->get_adaptor( $species || $self->species, 'core', 'slice' );
}

sub transcript_adaptor {
    my ( $self, $species ) = @_;
    return $self->registry->get_adaptor( $species || $self->species, 'core', 'transcript' );
}

sub constrained_element_adaptor {
    my ($self) = @_;
    return $self->registry->get_adaptor( 'Multi', 'compara', 'ConstrainedElement' );
}

sub repeat_feature_adaptor {
    my ( $self, $species ) = @_;
    return $self->registry->get_adaptor( $species || $self->species, 'core', 'repeatfeature' );
}

sub exon_adaptor {
    my ( $self, $species ) = @_;
    return $self->registry->get_adaptor( $species || $self->species, 'core', 'exon' );
}

__PACKAGE__->meta->make_immutable;

1;

__END__