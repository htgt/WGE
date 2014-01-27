package WGE::Model::Plugin::Design;

use Moose::Role;
use Hash::MoreUtils qw(slice_def);
use Log::Log4perl qw( :easy );

sub pspec_retrieve_design {
    return {
        id      => { validate => 'integer' },
        species => { validate => 'existing_species', rename => 'species_id', optional => 1 }
    };
}

sub retrieve_design {
    my ( $self, $params ) = @_;

    my $validated_params = $self->check_params( $params, $self->pspec_retrieve_design );

    my $design = $self->retrieve( Design => { slice_def $validated_params, qw( id species_id ) } );

    return $design;
}

# FIXME: factor this out of LIMS2??
sub pspec_create_design {
}

sub create_design{

}

1;