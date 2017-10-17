use utf8;
package WGE::Model::Schema::Result::CrisprsHuman;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::CrisprsHuman::VERSION = '0.109';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::CrisprsHuman

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

=head1 TABLE: C<crisprs_human>

=cut

__PACKAGE__->table("crisprs_human");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'crisprs_id_seq'

=head2 chr_name

  data_type: 'text'
  is_nullable: 0

=head2 chr_start

  data_type: 'integer'
  is_nullable: 0

=head2 seq

  data_type: 'text'
  is_nullable: 0

=head2 pam_right

  data_type: 'boolean'
  is_nullable: 0

=head2 species_id

  data_type: 'integer'
  is_nullable: 0

=head2 off_target_ids

  data_type: 'integer[]'
  is_nullable: 1

=head2 off_target_summary

  data_type: 'text'
  is_nullable: 1

=head2 exonic

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 genic

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "crisprs_id_seq",
  },
  "chr_name",
  { data_type => "text", is_nullable => 0 },
  "chr_start",
  { data_type => "integer", is_nullable => 0 },
  "seq",
  { data_type => "text", is_nullable => 0 },
  "pam_right",
  { data_type => "boolean", is_nullable => 0 },
  "species_id",
  { data_type => "integer", is_nullable => 0 },
  "off_target_ids",
  { data_type => "integer[]", is_nullable => 1 },
  "off_target_summary",
  { data_type => "text", is_nullable => 1 },
  "exonic",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "genic",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<crisprs_human_unique_loci>

=over 4

=item * L</chr_start>

=item * L</chr_name>

=item * L</pam_right>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "crisprs_human_unique_loci",
  ["chr_start", "chr_name", "pam_right"],
);

=head1 RELATIONS

=head2 crispr_pairs_human_lefts

Type: has_many

Related object: L<WGE::Model::Schema::Result::CrisprPairsHuman>

=cut

__PACKAGE__->has_many(
  "crispr_pairs_human_lefts",
  "WGE::Model::Schema::Result::CrisprPairsHuman",
  { "foreign.left_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 crispr_pairs_human_rights

Type: has_many

Related object: L<WGE::Model::Schema::Result::CrisprPairsHuman>

=cut

__PACKAGE__->has_many(
  "crispr_pairs_human_rights",
  "WGE::Model::Schema::Result::CrisprPairsHuman",
  { "foreign.right_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_crisprs_humans

Type: has_many

Related object: L<WGE::Model::Schema::Result::UserCrisprsHuman>

=cut

__PACKAGE__->has_many(
  "user_crisprs_humans",
  "WGE::Model::Schema::Result::UserCrisprsHuman",
  { "foreign.crispr_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-07-11 10:01:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GgsoXvCSgQ5Nkt52tNZBaQ




# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->might_have( ots_pending => 'WGE::Model::Schema::Result::CrisprOtPending', 'crispr_id' );

__PACKAGE__->many_to_many("users", "user_crisprs_humans", "user");

__PACKAGE__->meta->make_immutable;
1;
