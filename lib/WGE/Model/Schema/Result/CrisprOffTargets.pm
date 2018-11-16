use utf8;
package WGE::Model::Schema::Result::CrisprOffTargets;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::CrisprOffTargets::VERSION = '0.122';
}
## use critic


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
        exonic
        genic
    )
);

with 'WGE::Util::CrisprRole';
use Bio::Perl qw( revcom_as_string );

sub as_hash {
    my ( $self, $options ) = @_;

    my $data = {
        id                 => $self->id,
        crispr_id          => $self->parent_id, #this is the original crispr the ot belongs to
        chr_name           => $self->chr_name,
        chr_start          => $self->chr_start,
        chr_end            => $self->chr_end,
        pam_right          => $self->pam_right,
        pam_start          => $self->pam_start,
        species_id         => $self->species_id,
        exonic             => $self->exonic,
        genic              => $self->genic,
    };

    if ( $options->{always_pam_right} and $self->pam_left ) {
        $data->{seq} = revcom_as_string( $self->seq );
    }
    else {
        $data->{seq} = $self->seq;
    }

    return $data;
}

sub mismatches {
    my ( $self, $crispr_grna ) = @_;

    unless ( $crispr_grna ) {
        my $crispr = $self->result_source->schema->resultset('Crispr')->find( { id => $self->parent_id } );
        my $crispr_seq = $crispr->pam_right ? $crispr->seq : revcom_as_string( $crispr->seq );
        $crispr_grna = substr $crispr_seq, 0, 20;
    }

    my $ot_seq = $self->pam_right ? $self->seq : revcom_as_string( $self->seq );
    my $ot_grna = substr $ot_seq, 0, 20;

    return hamming_distance( $crispr_grna, $ot_grna );
}

=head2 hamming_distance

use string xor to get the number of mismatches between the two strings.
the xor returns a string with the binary digits of each char xor'd,
which will be an ascii char between 001 and 255. tr returns the number of characters replaced.

=cut
sub hamming_distance {
    die "Strings passed to hamming distance differ" if length($_[0]) != length($_[1]);
    return (uc($_[0]) ^ uc($_[1])) =~ tr/\001-\255//;
}

__PACKAGE__->set_primary_key( "id" );


__PACKAGE__->meta->make_immutable;

1;
