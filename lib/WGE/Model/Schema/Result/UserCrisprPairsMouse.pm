use utf8;
package WGE::Model::Schema::Result::UserCrisprPairsMouse;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::UserCrisprPairsMouse::VERSION = '0.079';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::UserCrisprPairsMouse

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

=head1 TABLE: C<user_crispr_pairs_mouse>

=cut

__PACKAGE__->table("user_crispr_pairs_mouse");

=head1 ACCESSORS

=head2 crispr_pair_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "crispr_pair_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</crispr_pair_id>

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("crispr_pair_id", "user_id");

=head1 RELATIONS

=head2 crispr_pair

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::CrisprPairsMouse>

=cut

__PACKAGE__->belongs_to(
  "crispr_pair",
  "WGE::Model::Schema::Result::CrisprPairsMouse",
  { id => "crispr_pair_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 user

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "WGE::Model::Schema::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-04-15 09:58:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mNNsYd4slYwTf56QAF05LA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
