use utf8;
package WGE::Model::Schema::Result::CrisprPair;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::CrisprPair

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

=head1 TABLE: C<crispr_pairs>

=cut

__PACKAGE__->table("crispr_pairs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'crispr_pairs_id_seq'

=head2 left_crispr_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 right_crispr_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 spacer

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "crispr_pairs_id_seq",
  },
  "left_crispr_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "right_crispr_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "spacer",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<crispr_pairs_left_crispr_id_right_crispr_id_key>

=over 4

=item * L</left_crispr_id>

=item * L</right_crispr_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "crispr_pairs_left_crispr_id_right_crispr_id_key",
  ["left_crispr_id", "right_crispr_id"],
);

=head1 RELATIONS

=head2 left_crispr

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Crispr>

=cut

__PACKAGE__->belongs_to(
  "left_crispr",
  "WGE::Model::Schema::Result::Crispr",
  { id => "left_crispr_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 right_crispr

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Crispr>

=cut

__PACKAGE__->belongs_to(
  "right_crispr",
  "WGE::Model::Schema::Result::Crispr",
  { id => "right_crispr_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2013-11-05 13:16:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1eUK3rCRK1ycBrjUYmfzLg

sub as_hash {
  my $self = shift;

  return {
    left_crispr  => $self->left_crispr->as_hash,
    right_crispr => $self->right_crispr->as_hash,
    spacer       => $self->spacer,
  };
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
