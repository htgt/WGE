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

=head2 left_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 right_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 spacer

  data_type: 'integer'
  is_nullable: 0

=head2 off_target_ids

  data_type: 'integer[]'
  is_nullable: 1

=head2 status

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 1

=head2 species_id

  data_type: 'integer'
  is_nullable: 0

=head2 off_target_summary

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "left_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "right_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "spacer",
  { data_type => "integer", is_nullable => 0 },
  "off_target_ids",
  { data_type => "integer[]", is_nullable => 1 },
  "status",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 1,
  },
  "species_id",
  { data_type => "integer", is_nullable => 0 },
  "off_target_summary",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</left_id>

=item * L</right_id>

=back

=cut

__PACKAGE__->set_primary_key("left_id", "right_id");

=head1 RELATIONS

=head2 left

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Crispr>

=cut

__PACKAGE__->belongs_to(
  "left",
  "WGE::Model::Schema::Result::Crispr",
  { id => "left_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 right

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Crispr>

=cut

__PACKAGE__->belongs_to(
  "right",
  "WGE::Model::Schema::Result::Crispr",
  { id => "right_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 status

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::CrisprPairStatus>

=cut

__PACKAGE__->belongs_to(
  "status",
  "WGE::Model::Schema::Result::CrisprPairStatus",
  { id => "status" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-01-28 16:41:34
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1coLGCBIqwPxJR2UxRVLtw

sub as_hash {
  my $self = shift;

  return {
    left_crispr        => $self->left->as_hash,
    right_crispr       => $self->right->as_hash,
    spacer             => $self->spacer,
    species_id         => $self->species_id,
    off_target_ids     => $self->off_target_ids,
    off_target_summary => $self->off_target_summary,
  };
}

sub off_targets {
  my $self = shift;

  #this resultset returns a list, where every even element is the left element
  #in a paired off target, and every odd element is the right.
  my @paired_offs = $self->result_source->schema->resultset('PairOffTargets')->search(
      {},
      { bind => [ $self->left_id, $self->right_id, $self->species_id, $self->species_id ] }
  );

  my @pairs;

  # get 2 entries at a time from the list
  while ( my ($left, $right) = splice( @paired_offs, 0, 2 ) ) {
    push @pairs, { left_crispr => $left, right_crispr => $right };
  }

  return wantarray ? @pairs : \@pairs;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
