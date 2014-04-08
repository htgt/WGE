use utf8;
package WGE::Model::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::User

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

=head1 TABLE: C<users>

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'users_id_seq'

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 password

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "users_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "password",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<users_name_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("users_name_key", ["name"]);

=head1 RELATIONS

=head2 design_attempts

Type: has_many

Related object: L<WGE::Model::Schema::Result::DesignAttempt>

=cut

__PACKAGE__->has_many(
  "design_attempts",
  "WGE::Model::Schema::Result::DesignAttempt",
  { "foreign.created_by" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 design_comments

Type: has_many

Related object: L<WGE::Model::Schema::Result::DesignComment>

=cut

__PACKAGE__->has_many(
  "design_comments",
  "WGE::Model::Schema::Result::DesignComment",
  { "foreign.created_by" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 designs

Type: has_many

Related object: L<WGE::Model::Schema::Result::Design>

=cut

__PACKAGE__->has_many(
  "designs",
  "WGE::Model::Schema::Result::Design",
  { "foreign.created_by" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 gene_designs

Type: has_many

Related object: L<WGE::Model::Schema::Result::GeneDesign>

=cut

__PACKAGE__->has_many(
  "gene_designs",
  "WGE::Model::Schema::Result::GeneDesign",
  { "foreign.created_by" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_crispr_pairs_humans

Type: has_many

Related object: L<WGE::Model::Schema::Result::UserCrisprPairsHuman>

=cut

__PACKAGE__->has_many(
  "user_crispr_pairs_humans",
  "WGE::Model::Schema::Result::UserCrisprPairsHuman",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_crispr_pairs_mice

Type: has_many

Related object: L<WGE::Model::Schema::Result::UserCrisprPairsMouse>

=cut

__PACKAGE__->has_many(
  "user_crispr_pairs_mice",
  "WGE::Model::Schema::Result::UserCrisprPairsMouse",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_crisprs_humans

Type: has_many

Related object: L<WGE::Model::Schema::Result::UserCrisprsHuman>

=cut

__PACKAGE__->has_many(
  "user_crisprs_humans",
  "WGE::Model::Schema::Result::UserCrisprsHuman",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_crisprs_mice

Type: has_many

Related object: L<WGE::Model::Schema::Result::UserCrisprsMouse>

=cut

__PACKAGE__->has_many(
  "user_crisprs_mice",
  "WGE::Model::Schema::Result::UserCrisprsMouse",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 crispr_pairs

Type: many_to_many

Composing rels: L</user_crispr_pairs_mice> -> crispr_pair

=cut

__PACKAGE__->many_to_many("crispr_pairs", "user_crispr_pairs_mice", "crispr_pair");

=head2 crispr_pairs_2s

Type: many_to_many

Composing rels: L</user_crispr_pairs_humans> -> crispr_pair

=cut

__PACKAGE__->many_to_many("crispr_pairs_2s", "user_crispr_pairs_humans", "crispr_pair");

=head2 crisprs

Type: many_to_many

Composing rels: L</user_crisprs_humans> -> crispr

=cut

__PACKAGE__->many_to_many("crisprs", "user_crisprs_humans", "crispr");

=head2 crisprs_2s

Type: many_to_many

Composing rels: L</user_crisprs_mice> -> crispr

=cut

__PACKAGE__->many_to_many("crisprs_2s", "user_crisprs_mice", "crispr");


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-04-07 13:53:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:X6R7FtDL+jNfNFMp4dlJ8A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
sub user_crisprs{
    my $self = shift;

    return ($self->user_crisprs_humans, $self->user_crisprs_mice);
}

sub user_crispr_pairs{
    my $self = shift;

    return ($self->user_crispr_pairs_humans, $self->user_crispr_pairs_mice);
}

__PACKAGE__->meta->make_immutable;
1;
