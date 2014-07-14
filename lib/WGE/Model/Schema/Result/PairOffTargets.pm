use utf8;
package WGE::Model::Schema::Result::PairOffTargets;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::PairOffTargets::VERSION = '0.032';
}
## use critic


=head1 NAME

WGE::Model::Schema::Result::PairsForCrispr

=head1 DESCRIPTION

Custom view that returns all off targets for two crisprs

=cut

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

__PACKAGE__->table_class( 'DBIx::Class::ResultSource::View' );
__PACKAGE__->table( 'exon_crisprs' );

__PACKAGE__->result_source_instance->is_virtual(1);

#the with returns a list of off target ids and their original order.
#technically this is undefined behaviour, and the behaviour for running
#over with no order by could change. Pg 9.4 will introduce WITH ORDINALITY,
#which will do exactly this. So don't upgrade pg until 9.4 is out or things 
#might break. when we have 9.4 change to use WITH ORDINALITY
__PACKAGE__->result_source_instance->view_definition( <<'EOT' );
with ots as (
    select *, row_number() over() from ( 
        select unnest(off_target_ids) as ot_id 
        from crispr_pairs 
        where left_id=? and right_id=? and species_id=?
    ) ids
)
select c.*
from ots
join crisprs c on c.id=ots.ot_id and c.species_id=?
order by ots.row_number
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

with 'WGE::Util::CrisprRole';

sub as_hash {
    my $self = shift;

    return {
        id        => $self->id,
        chr_name  => $self->chr_name,
        chr_start => $self->chr_start,
        chr_end   => $self->chr_end,
        pam_right => $self->pam_right,
        seq       => $self->seq,
    }
}


__PACKAGE__->meta->make_immutable;

1;
