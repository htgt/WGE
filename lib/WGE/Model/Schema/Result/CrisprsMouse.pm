use utf8;
package WGE::Model::Schema::Result::CrisprsMouse;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::CrisprsMouse

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

=head1 TABLE: C<crisprs_mouse>

=cut

__PACKAGE__->table("crisprs_mouse");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'crisprs_id_seq'

=head2 chr_start

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

  data_type: 'integer'
  is_nullable: 0

=head2 off_targets

  data_type: 'integer[]'
  is_nullable: 1

=head2 off_target_summary

  data_type: 'text'
  is_nullable: 1

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
  "chr_name",
  { data_type => "text", is_nullable => 0 },
  "seq",
  { data_type => "text", is_nullable => 0 },
  "pam_right",
  { data_type => "boolean", is_nullable => 0 },
  "species_id",
  { data_type => "integer", is_nullable => 0 },
  "off_targets",
  { data_type => "integer[]", is_nullable => 1 },
  "off_target_summary",
  { data_type => "text", is_nullable => 1 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<crispr_mouse_unique_loci>

=over 4

=item * L</chr_start>

=item * L</chr_name>

=item * L</pam_right>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "crispr_mouse_unique_loci",
  ["chr_start", "chr_name", "pam_right"],
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-01-23 10:25:34
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GUKWnROw+rpDGCm/OArh5g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->set_primary_key('id');
__PACKAGE__->meta->make_immutable;
1;
