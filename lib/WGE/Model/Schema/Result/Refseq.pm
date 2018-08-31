use utf8;
package WGE::Model::Schema::Result::Refseq;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Refseq

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

=head1 TABLE: C<refseq>

=cut

__PACKAGE__->table("refseq");

=head1 ACCESSORS

=head2 id

  data_type: 'text'
  is_nullable: 0

=head2 feature_type_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 chr_name

  data_type: 'text'
  is_nullable: 0

=head2 chr_start

  data_type: 'integer'
  is_nullable: 0

=head2 chr_end

  data_type: 'integer'
  is_nullable: 0

=head2 strand

  data_type: 'integer'
  is_nullable: 0

=head2 rank

  data_type: 'integer'
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 parent_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 1

=head2 gene_type

  data_type: 'text'
  is_nullable: 1

=head2 gene_id

  data_type: 'text'
  is_nullable: 1

=head2 transcript_id

  data_type: 'text'
  is_nullable: 1

=head2 protein_id

  data_type: 'text'
  is_nullable: 1

=head2 biotype

  data_type: 'text'
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "text", is_nullable => 0 },
  "feature_type_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "chr_name",
  { data_type => "text", is_nullable => 0 },
  "chr_start",
  { data_type => "integer", is_nullable => 0 },
  "chr_end",
  { data_type => "integer", is_nullable => 0 },
  "strand",
  { data_type => "integer", is_nullable => 0 },
  "rank",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "parent_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 1 },
  "gene_type",
  { data_type => "text", is_nullable => 1 },
  "gene_id",
  { data_type => "text", is_nullable => 1 },
  "transcript_id",
  { data_type => "text", is_nullable => 1 },
  "protein_id",
  { data_type => "text", is_nullable => 1 },
  "biotype",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 feature_type

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::FeatureType>

=cut

__PACKAGE__->belongs_to(
  "feature_type",
  "WGE::Model::Schema::Result::FeatureType",
  { id => "feature_type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 parent

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Refseq>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "WGE::Model::Schema::Result::Refseq",
  { id => "parent_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 refseqs

Type: has_many

Related object: L<WGE::Model::Schema::Result::Refseq>

=cut

__PACKAGE__->has_many(
  "refseqs",
  "WGE::Model::Schema::Result::Refseq",
  { "foreign.parent_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2018-08-23 14:19:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vUMnfTWzmzEJNRls+uxNDw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

