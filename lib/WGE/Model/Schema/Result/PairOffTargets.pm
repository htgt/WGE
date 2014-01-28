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

#given two crispr ids find any paired off targets.
#we are assuming they are a pair
#can maybe be sped up by doing a join instead of IN, see CrisprByExon
__PACKAGE__->result_source_instance->view_definition( <<'EOT' );
with ots as (
    select id as crispr_id, unnest(off_target_ids) as ot_id, species_id 
    from crisprs 
    where species_id=? and (id=? or id=?)
)
select 
    ots.ot_id as id, 
    ots.crispr_id as crispr_id,
    c.chr_name as chr_name, 
    c.chr_start as chr_start, 
    c.pam_right as pam_right
from ots
join crisprs c on c.id=ots.ot_id and c.species_id=ots.species_id
order by ots.crispr_id, c.chr_name, c.chr_start
EOT

#something like this for an exon? we still dont know which ones are pairs though...
#also it takes about 10 minutes.
# <<'EOT'
# with ots as (
#     select c.id as crispr_id, unnest(off_target_ids) as ot_id from exons e
#     join crisprs c on c.chr_name=e.chr_name AND c.chr_start>=(e.chr_start-22) AND c.chr_start<=e.chr_end
#     where exons.ensembl_exon_id=? and species_id=?
# )
# select 
#     ots.crispr_id, 
#     c.chr_name as chr_name, 
#     array_agg(ots.ot_id) as ot_id, 
#     array_agg(c.chr_start) as chr_start, 
#     array_agg(c.pam_right) as pam_right
# from ots
# join crisprs c on c.id=ots.ot_id
# group by ots.crispr_id, c.chr_name;
# EOT

__PACKAGE__->add_columns(
    qw(
        crispr_id
        chr_name
        id
        chr_start
        pam_right
    )
);

__PACKAGE__->set_primary_key( "crispr_id" );

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
