use utf8;
package WGE::Model::Schema::Result::DesignOligo;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::DesignOligo::VERSION = '0.079';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::DesignOligo

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<design_oligos>

=cut

__PACKAGE__->table("design_oligos");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'design_oligos_id_seq'

=head2 design_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 design_oligo_type_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 seq

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "design_oligos_id_seq",
  },
  "design_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "design_oligo_type_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "seq",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<design_oligos_design_id_design_oligo_type_id_key>

=over 4

=item * L</design_id>

=item * L</design_oligo_type_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "design_oligos_design_id_design_oligo_type_id_key",
  ["design_id", "design_oligo_type_id"],
);

=head1 RELATIONS

=head2 design

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Design>

=cut

__PACKAGE__->belongs_to(
  "design",
  "WGE::Model::Schema::Result::Design",
  { id => "design_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 design_oligo_locis

Type: has_many

Related object: L<WGE::Model::Schema::Result::DesignOligoLoci>

=cut

__PACKAGE__->has_many(
  "design_oligo_locis",
  "WGE::Model::Schema::Result::DesignOligoLoci",
  { "foreign.design_oligo_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 design_oligo_type

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::DesignOligoType>

=cut

__PACKAGE__->belongs_to(
  "design_oligo_type",
  "WGE::Model::Schema::Result::DesignOligoType",
  { id => "design_oligo_type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-01-23 10:25:34
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gL33AnAP0BWgXxlFm7ROng


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->has_many(
  "loci",
  "WGE::Model::Schema::Result::DesignOligoLoci",
  { "foreign.design_oligo_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

use Try::Tiny;

sub as_hash {
    my $self = shift;

    return {
        id    => $self->id,
        type  => $self->design_oligo_type_id,
        seq   => $self->seq,
        locus => $self->locus ? $self->locus->as_hash : undef
    };
}

sub locus {
    my $self = shift;

    my $locus;
    if ( my $default_assembly = $self->design->species->default_assembly ) {
        $locus = $self->search_related( 'loci', { assembly_id => $default_assembly->assembly_id } )->first;
    }
    return $locus;
}

=head2 oligo_strand_vs_design_strand

What is the orientation of the oligo in relation to the strand of the design it belongs to.
1 means it is the same strand as the design, -1 means it is the opposite strand to the design.
Remember, all oligo sequence is stored on the +ve strand, no matter the design strand.

For example, the U5 oligo is on the same strand as the design ( 1 )
So a U5 oligo for a +ve stranded design is on the +ve strand ( i.e do not revcomp )
Conversely, a U5 oligo for a -ve stranded design is on the -ve strand ( i.e revcomp it )

The U3 oligo is on the opposite strand as the design ( -1 )
So a U3 oligo for a +ve stranded design is on the -ve strand ( i.e revcomp it )
Conversely, a U3 oligo for a -ve stranded design is on the +ve strand ( i.e do not revcomp )

=cut
my %OLIGO_STRAND_VS_DESIGN_STRAND = (
    "G5" => -1,
    "U5" => 1,
    "U3" => -1,
    "D5" => 1,
    "D3" => -1,
    "G3" => 1,
    "5F" => 1,
    "5R" => -1,
    "EF" => 1,
    "ER" => -1,
    "3F" => 1,
    "3R" => -1,
);

=head2 oligo_order_seq

Sequence used when ordering the oligo.
Need to revcomp if needed.

Send in optional design strand and design type to avoid extra DB calls.

=cut
sub oligo_order_seq {
    my ( $self, $design_strand, $design_type ) = @_;
    $design_strand ||= $self->locus->chr_strand;
    $design_type   ||= $self->design->design_type_id;

    # See comment above %OLIGO_STRAND_VS_DESIGN_STRAND for explanation
    my $oligo_strand = $OLIGO_STRAND_VS_DESIGN_STRAND{ $self->design_oligo_type_id };
    my $seq = $design_strand != $oligo_strand ? $self->revcomp_seq : $self->seq;

    return $seq;
}

=head2 revcomp_seq

Return reverse complimented oligo sequence.

=cut
sub revcomp_seq {
    my $self = shift;
    my $revcomp_seq;

    require Bio::Seq;
    require LIMS2::Exception;

    try{
        # -verbose -1 turns of warning / error messages
        my $bio_seq = Bio::Seq->new( -alphabet => 'dna', -seq => $self->seq, -verbose => -1 );
        $revcomp_seq = $bio_seq->revcom->seq;
    }
    catch {
        LIMS2::Exception->throw( 'Error working out revcomp of sequence: ' . $self->seq );
    };

    return $revcomp_seq;
}

__PACKAGE__->meta->make_immutable;
1;
