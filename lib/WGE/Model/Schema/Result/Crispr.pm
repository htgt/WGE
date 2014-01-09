use utf8;
package WGE::Model::Schema::Result::Crispr;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Crispr

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

=head1 TABLE: C<crisprs>

=cut

__PACKAGE__->table("crisprs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'crisprs_id_seq'

=head2 chr_start

  data_type: 'integer'
  is_nullable: 0

=head2 chr_end

  data_type: 'integer'
  is_nullable: 0

=head2 chr_name

  data_type: 'text'
  is_nullable: 0

=head2 seq

  data_type: 'text'
  is_nullable: 0

=head2 pam_right

  data_type: 'boolean'
  is_nullable: 0

=head2 species_id

  data_type: 'text'
  is_foreign_key: 1
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
  "chr_start",
  { data_type => "integer", is_nullable => 0 },
  "chr_end",
  { data_type => "integer", is_nullable => 0 },
  "chr_name",
  { data_type => "text", is_nullable => 0 },
  "seq",
  { data_type => "text", is_nullable => 0 },
  "pam_right",
  { data_type => "boolean", is_nullable => 0 },
  "species_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 crispr_pairs_left_crisprs

Type: has_many

Related object: L<WGE::Model::Schema::Result::CrisprPair>

=cut

__PACKAGE__->has_many(
  "crispr_pairs_left_crisprs",
  "WGE::Model::Schema::Result::CrisprPair",
  { "foreign.left_crispr_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 crispr_pairs_right_crisprs

Type: has_many

Related object: L<WGE::Model::Schema::Result::CrisprPair>

=cut

__PACKAGE__->has_many(
  "crispr_pairs_right_crisprs",
  "WGE::Model::Schema::Result::CrisprPair",
  { "foreign.right_crispr_id" => "self.id" },
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


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2013-11-06 19:53:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sJH9Ev+ScN5pRhgxbMOiKA

sub as_hash {
  my $self = shift;

  #should just do a map on $self->columns...
  return {
    chr_name  => $self->chr_name,
    chr_start => $self->chr_start,
    chr_end   => $self->chr_end,
    seq       => $self->seq,
    species   => $self->species_id,
    pam_right => $self->pam_right,
  };
}

sub pairs {
  my $self = shift;

  return ($self->pam_right) ? $self->crispr_pairs_right_crisprs : $self->crispr_pairs_left_crisprs;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
