use utf8;
package WGE::Model::Schema::Result::UserHaplotype;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::UserHaplotype::VERSION = '0.121';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::UserHaplotype

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

=head1 TABLE: C<user_haplotype>

=cut

__PACKAGE__->table("user_haplotype");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 haplotype_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "haplotype_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 RELATIONS

=head2 haplotype

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Haplotype>

=cut

__PACKAGE__->belongs_to(
  "haplotype",
  "WGE::Model::Schema::Result::Haplotype",
  { id => "haplotype_id" },
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


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2018-09-03 10:37:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Pkz3jUnWUaNsGS8UIODyBw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
