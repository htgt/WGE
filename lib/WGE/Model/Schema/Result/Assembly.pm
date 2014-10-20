use utf8;
package WGE::Model::Schema::Result::Assembly;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::Assembly::VERSION = '0.049';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Assembly

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

=head1 TABLE: C<assemblies>

=cut

__PACKAGE__->table("assemblies");

=head1 ACCESSORS

=head2 id

  data_type: 'text'
  is_nullable: 0

=head2 species_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "text", is_nullable => 0 },
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

=head2 design_oligo_locis

Type: has_many

Related object: L<WGE::Model::Schema::Result::DesignOligoLoci>

=cut

__PACKAGE__->has_many(
  "design_oligo_locis",
  "WGE::Model::Schema::Result::DesignOligoLoci",
  { "foreign.assembly_id" => "self.id" },
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

=head2 species_default_assemblies

Type: has_many

Related object: L<WGE::Model::Schema::Result::SpeciesDefaultAssembly>

=cut

__PACKAGE__->has_many(
  "species_default_assemblies",
  "WGE::Model::Schema::Result::SpeciesDefaultAssembly",
  { "foreign.assembly_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-01-23 10:25:34
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GL2rD+M/VwY7HOGPdHIPQA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
