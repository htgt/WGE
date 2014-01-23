package WGE::Model::Plugin::DesignAttempt;

use Moose::Role;
use Hash::MoreUtils qw(slice_def);
use Log::Log4perl qw( :easy );

sub pspec_create_design_attempt {
    return {
        design_parameters => { validate => 'json', optional => 1 },
        gene_id           => { validate => 'non_empty_string' },
        status            => { validate => 'non_empty_string', optional => 1 },
        fail              => { validate => 'json', optional => 1 },
        error             => { validate => 'non_empty_string', optional => 1 },
        design_ids        => { validate => 'non_empty_string', optional => 1 },
        species           => { validate => 'existing_species', rename => 'species_id' },
        created_at        => { validate => 'date_time', post_filter => 'parse_date_time', optional => 1 },
        created_by        => { validate => 'existing_user', post_filter => 'user_id_for'},
        comment           => { optional => 1 },
    }
}

sub create_design_attempt {
    my ( $self, $params ) = @_;

    my $validated_params = $self->check_params( $params, $self->pspec_create_design_attempt );

    my $design_attempt = $self->schema->resultset( 'DesignAttempt' )->create(
        {
            slice_def (
                $validated_params,
                qw ( design_parameters gene_id status fail error species_id
                     design_ids created_at created_by comment
                   )
            )
        }
    );
    DEBUG( 'Created design attempt ' . $design_attempt->id );

    return $design_attempt;
}

1;