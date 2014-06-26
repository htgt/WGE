use utf8;
package WGE::Model::Schema::Result::DesignOligo;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::DesignOligo::VERSION = '0.024';
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

__PACKAGE__->meta->make_immutable;
1;
