use utf8;
package WGE::Model::Schema::Result::PairOffTargets;

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



#this will be to check if db entries exist
<<EOT;
with s as (
    select left_id, right_id from (
        select unnest(?::int[]) as left_id, unnest(?::int[]) as right_id
    ) x
)
select cp.* from s
join crispr_pairs cp on cp.left_id=s.left_id and cp.right_id=s.right_id
where species_id=?
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

#CHECK THESE NUMBERS. we want either the start or end of sgrna
sub pam_start {
    my $self = shift;
    return $self->chr_start + ($self->pam_right ? 19 : 2)
}

sub pam_left {
    return ! shift->pam_right;
}

sub as_hash {
    my $self = shift;

    return {
        id        => $self->id,
        crispr_id => $self->crispr_id, #this is the original crispr the ot belongs to
        chr_name  => $self->chr_name,
        chr_start => $self->chr_start,
        pam_right => $self->pam_right,
    }
}


__PACKAGE__->meta->make_immutable;

1;
