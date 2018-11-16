use utf8;
package WGE::Model::Schema::Result::User;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::User::VERSION = '0.122';
}
## use critic


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

=head2 library_design_jobs

Type: has_many

Related object: L<WGE::Model::Schema::Result::LibraryDesignJob>

=cut

__PACKAGE__->has_many(
  "library_design_jobs",
  "WGE::Model::Schema::Result::LibraryDesignJob",
  { "foreign.created_by_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_crispr_pairs_grch38s

Type: has_many

Related object: L<WGE::Model::Schema::Result::UserCrisprPairsGrch38>

=cut

__PACKAGE__->has_many(
  "user_crispr_pairs_grch38s",
  "WGE::Model::Schema::Result::UserCrisprPairsGrch38",
  { "foreign.user_id" => "self.id" },
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

=head2 user_crisprs_grch38s

Type: has_many

Related object: L<WGE::Model::Schema::Result::UserCrisprsGrch38>

=cut

__PACKAGE__->has_many(
  "user_crisprs_grch38s",
  "WGE::Model::Schema::Result::UserCrisprsGrch38",
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

=head2 user_haplotypes

Type: has_many

Related object: L<WGE::Model::Schema::Result::UserHaplotype>

=cut

__PACKAGE__->has_many(
  "user_haplotypes",
  "WGE::Model::Schema::Result::UserHaplotype",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2018-09-03 11:41:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7v9gKEBIAQnX38a0UgOp6Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration

sub user_crisprs {
  my $self = shift;

  return ( $self->user_crisprs_grch38s, $self->user_crisprs_humans, $self->user_crisprs_mice );
}

sub user_crispr_pairs {
  my $self = shift;

  return ( $self->user_crispr_pairs_grch38s, $self->user_crispr_pairs_humans, $self->user_crispr_pairs_mice );
}

sub _species_crisprs {
  my ( $self, $species ) = @_;

  #e.g. user_crisprs_mouse
  my $field = "user_crisprs_" . $species;

  return map { $self->result_source->schema->resultset('Crispr')->find({ id => $_->crispr_id }) }
            $self->$field;
}

sub _species_crispr_pairs {
  my ( $self, $species ) = @_;

  #e.g. user_crisprs_mouse
  my $field = "user_crispr_pairs_" . $species;

  return map { $self->result_source->schema->resultset('CrisprPair')->find({ id => $_->crispr_pair_id }) }
            $self->$field;
}

# many-to-many relationship would return MouseCrispr so we do this instead:

#should do this using $self->meta->add_method based on species table maybe
sub mouse_crisprs { return shift->_species_crisprs( 'mice' ); }
sub human_crisprs { return shift->_species_crisprs( 'humans' ); }
sub grch38_crisprs { return shift->_species_crisprs( 'grch38s' ); }

sub mouse_crispr_pairs { return shift->_species_crispr_pairs( 'mice' ); }
sub human_crispr_pairs { return shift->_species_crispr_pairs( 'humans' ); }
sub grch38_crispr_pairs { return shift->_species_crispr_pairs( 'grch38s' ); }

__PACKAGE__->meta->make_immutable;
1;

