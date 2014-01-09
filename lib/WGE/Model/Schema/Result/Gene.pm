use utf8;
package WGE::Model::Schema::Result::Gene;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Gene

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

=head1 TABLE: C<genes>

=cut

__PACKAGE__->table("genes");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'genes_id_seq'

=head2 species_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 marker_symbol

  data_type: 'text'
  is_nullable: 0

=head2 ensembl_gene_id

  data_type: 'text'
  is_nullable: 0

=head2 chr_start

  data_type: 'integer'
  is_nullable: 0

=head2 chr_end

  data_type: 'integer'
  is_nullable: 0

=head2 chr_name

  data_type: 'text'
  is_nullable: 0

=head2 strand

  data_type: 'integer'
  is_nullable: 0

=head2 canonical_transcript

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "genes_id_seq",
  },
  "species_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "marker_symbol",
  { data_type => "text", is_nullable => 0 },
  "ensembl_gene_id",
  { data_type => "text", is_nullable => 0 },
  "chr_start",
  { data_type => "integer", is_nullable => 0 },
  "chr_end",
  { data_type => "integer", is_nullable => 0 },
  "chr_name",
  { data_type => "text", is_nullable => 0 },
  "strand",
  { data_type => "integer", is_nullable => 0 },
  "canonical_transcript",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<genes_ensembl_gene_id_key>

=over 4

=item * L</ensembl_gene_id>

=back

=cut

__PACKAGE__->add_unique_constraint("genes_ensembl_gene_id_key", ["ensembl_gene_id"]);

=head2 C<genes_species_id_marker_symbol_key>

=over 4

=item * L</species_id>

=item * L</marker_symbol>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "genes_species_id_marker_symbol_key",
  ["species_id", "marker_symbol"],
);

=head1 RELATIONS

=head2 exons

Type: has_many

Related object: L<WGE::Model::Schema::Result::Exon>

=cut

__PACKAGE__->has_many(
  "exons",
  "WGE::Model::Schema::Result::Exon",
  { "foreign.gene_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 species

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Species>

=cut

__PACKAGE__->belongs_to(
  "species",
  "WGE::Model::Schema::Result::Species",
  { id => "species_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2013-11-27 17:14:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OPfOxFPOs7mDYEUoqfiNWQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
