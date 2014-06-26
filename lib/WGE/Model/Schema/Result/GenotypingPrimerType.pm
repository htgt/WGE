use utf8;
package WGE::Model::Schema::Result::GenotypingPrimerType;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::GenotypingPrimerType::VERSION = '0.025';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::GenotypingPrimerType

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

=head1 TABLE: C<genotyping_primer_types>

=cut

__PACKAGE__->table("genotyping_primer_types");

=head1 ACCESSORS

=head2 id

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns("id", { data_type => "text", is_nullable => 0 });

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 genotyping_primers

Type: has_many

Related object: L<WGE::Model::Schema::Result::GenotypingPrimer>

=cut

__PACKAGE__->has_many(
  "genotyping_primers",
  "WGE::Model::Schema::Result::GenotypingPrimer",
  { "foreign.genotyping_primer_type_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-01-23 10:25:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HvP9LNS8zcVK00lphb+LOw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
