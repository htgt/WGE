use utf8;
package WGE::Model::Schema::Result::CrisprPairStatus;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::CrisprPairStatus::VERSION = '0.035';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::CrisprPairStatus

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

=head1 TABLE: C<crispr_pair_statuses>

=cut

__PACKAGE__->table("crispr_pair_statuses");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

=head2 status

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "status",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 crispr_pairs

Type: has_many

Related object: L<WGE::Model::Schema::Result::CrisprPair>

=cut

__PACKAGE__->has_many(
  "crispr_pairs",
  "WGE::Model::Schema::Result::CrisprPair",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 crispr_pairs_humans

Type: has_many

Related object: L<WGE::Model::Schema::Result::CrisprPairsHuman>

=cut

__PACKAGE__->has_many(
  "crispr_pairs_humans",
  "WGE::Model::Schema::Result::CrisprPairsHuman",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 crispr_pairs_mice

Type: has_many

Related object: L<WGE::Model::Schema::Result::CrisprPairsMouse>

=cut

__PACKAGE__->has_many(
  "crispr_pairs_mice",
  "WGE::Model::Schema::Result::CrisprPairsMouse",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-02-18 14:32:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aciMkUHuNbMMsbpoQfmN8A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
