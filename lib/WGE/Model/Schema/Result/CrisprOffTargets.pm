use utf8;
package WGE::Model::Schema::Result::CrisprOffTargets;

=head1 NAME

WGE::Model::Schema::Result::CrisprOffTargets

=head1 DESCRIPTION

Custom view that selects all off targets for 1 or more crisprs

Bound value are:
1. an array of crispr ids (some examples: '{1}' or '{1,2,3}')
2. species_id
3. species_id (again, because the query planner needs the actual value to exclude tables)

=cut

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

__PACKAGE__->table_class( 'DBIx::Class::ResultSource::View' );
__PACKAGE__->table( 'crispr_off_targets' );

__PACKAGE__->result_source_instance->is_virtual(1);

#we need species twice so the query won't ever search the wrong table
__PACKAGE__->result_source_instance->view_definition( <<'EOT' );
with ots as (
    select x.crispr_id, unnest(off_target_ids) as ot_id
    from (SELECT unnest(?::int[]) as crispr_id) x 
    join crisprs on crisprs.id=x.crispr_id and crisprs.species_id=?
)
select  
    ots.crispr_id as parent_id,
    c.*
from ots
join crisprs c on c.id=ots.ot_id and c.species_id=?
order by ots.crispr_id, c.chr_name, c.chr_start
EOT

__PACKAGE__->add_columns(
    qw(
        id
        parent_id
        chr_name
        chr_start
        seq 
        pam_right
        species_id
        off_target_ids
        off_target_summary
    )
);

with 'WGE::Util::CrisprRole';

__PACKAGE__->set_primary_key( "id" );


__PACKAGE__->meta->make_immutable;

1;