use utf8;
package WGE::Model::Schema::Result::CrisprOtPending;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::CrisprOtPending::VERSION = '0.097';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::CrisprOtPending

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

=head1 TABLE: C<crispr_ots_pending>

=cut

__PACKAGE__->table("crispr_ots_pending");

=head1 ACCESSORS

=head2 crispr_id

  data_type: 'integer'
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "crispr_id",
  { data_type => "integer", is_nullable => 0 },
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

=item * L</crispr_id>

=back

=cut

__PACKAGE__->set_primary_key("crispr_id");


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-06-26 14:44:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kBbQslbPm9sGxTlJx9LJWw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
