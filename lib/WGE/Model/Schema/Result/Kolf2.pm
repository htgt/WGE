use utf8;
package WGE::Model::Schema::Result::Kolf2;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Kolf2

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

=head1 TABLE: C<kolf2>

=cut

__PACKAGE__->table("kolf2");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'kolf2_id_seq'

=head2 chrom

  data_type: 'text'
  is_nullable: 0

=head2 pos

  data_type: 'integer'
  is_nullable: 0

=head2 ref

  data_type: 'text'
  is_nullable: 0

=head2 alt

  data_type: 'text'
  is_nullable: 0

=head2 qual

  data_type: 'numeric'
  is_nullable: 1

=head2 filter

  data_type: 'text'
  is_nullable: 1

=head2 genome_phasing

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "kolf2_id_seq",
  },
  "chrom",
  { data_type => "text", is_nullable => 0 },
  "pos",
  { data_type => "integer", is_nullable => 0 },
  "ref",
  { data_type => "text", is_nullable => 0 },
  "alt",
  { data_type => "text", is_nullable => 0 },
  "qual",
  { data_type => "numeric", is_nullable => 1 },
  "filter",
  { data_type => "text", is_nullable => 1 },
  "genome_phasing",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2018-07-04 14:36:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k4/bBUb4NybFXUarizSUDg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
