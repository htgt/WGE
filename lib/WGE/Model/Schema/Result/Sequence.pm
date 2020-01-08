use utf8;
package WGE::Model::Schema::Result::Sequence;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Sequence

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

=head1 TABLE: C<sequences>

=cut

__PACKAGE__->table("sequences");

=head1 ACCESSORS

=head2 crispr_id

  data_type: 'integer'
  is_nullable: 0

=head2 seq_id

  data_type: 'bigint'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "crispr_id",
  { data_type => "integer", is_nullable => 0 },
  "seq_id",
  { data_type => "bigint", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</crispr_id>

=back

=cut

__PACKAGE__->set_primary_key("crispr_id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-12-06 15:38:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:D8UTtNQNVnOBwIrDY52EWA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->might_have( off_target => 'WGE::Model::Schema::Result::OffTarget',
    { 'foreign.seq_id' => 'self.seq_id' });
__PACKAGE__->meta->make_immutable;
1;
