use utf8;
package WGE::Model::Schema::Result::CrisprPairsHuman;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::CrisprPairsHuman::VERSION = '0.032';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::CrisprPairsHuman

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

=head1 TABLE: C<crispr_pairs_human>

=cut

__PACKAGE__->table("crispr_pairs_human");

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

=head2 status_id

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

=head2 last_modified

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 id

  data_type: 'text'
  is_nullable: 0

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
  "status_id",
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
  "last_modified",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "id",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</left_id>

=item * L</right_id>

=back

=cut

__PACKAGE__->set_primary_key("left_id", "right_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_human_pair_id>

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_human_pair_id", ["id"]);

=head1 RELATIONS

=head2 left

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::CrisprsHuman>

=cut

__PACKAGE__->belongs_to(
  "left",
  "WGE::Model::Schema::Result::CrisprsHuman",
  { id => "left_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 right

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::CrisprsHuman>

=cut

__PACKAGE__->belongs_to(
  "right",
  "WGE::Model::Schema::Result::CrisprsHuman",
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
  { id => "status_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 user_crispr_pairs_humans

Type: has_many

Related object: L<WGE::Model::Schema::Result::UserCrisprPairsHuman>

=cut

__PACKAGE__->has_many(
  "user_crispr_pairs_humans",
  "WGE::Model::Schema::Result::UserCrisprPairsHuman",
  { "foreign.crispr_pair_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-04-15 09:58:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:74jmVVUmfTRXAA0ylr5Fqw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->many_to_many("users", "user_crispr_pairs_humans", "user");

__PACKAGE__->meta->make_immutable;
1;
