use utf8;
package WGE::Model::Schema::Result::CrisprOffTargets;

=head1 NAME

WGE::Model::Schema::Result::CrisprOffTargets

=head1 DESCRIPTION

Custom view that selects all off targets for a given crispr

=cut

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

__PACKAGE__->table_class( 'DBIx::Class::ResultSource::View' );
__PACKAGE__->table( 'crispr_off_targets' );

__PACKAGE__->result_source_instance->is_virtual(1);

#we use species so the query won't ever search the wrong table
__PACKAGE__->result_source_instance->view_definition( <<'EOT' );
with ots as (
    select unnest(off_target_ids) as id, species_id
    from crisprs
    where id=? and species_id=?
)
select c.* from ots
join crisprs c on c.id=ots.id and c.species_id=ots.species_id
EOT

__PACKAGE__->add_columns(
    qw(
        id
        chr_name
        chr_start
        seq 
        pam_right
        species_id
        off_target_ids
        off_target_summary
    )
);

__PACKAGE__->set_primary_key( "id" );


__PACKAGE__->meta->make_immutable;

1;