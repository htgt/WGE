use utf8;
package WGE::Model::Schema::Result::Species;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::Species::VERSION = '0.099';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Species

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

=head1 TABLE: C<species>

=cut

__PACKAGE__->table("species");

=head1 ACCESSORS

=head2 numerical_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'species_id_seq'

=head2 id

  data_type: 'text'
  is_nullable: 0

=head2 display_name

  data_type: 'text'
  is_nullable: 0

=head2 active

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "numerical_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "species_id_seq",
  },
  "id",
  { data_type => "text", is_nullable => 0 },
  "display_name",
  { data_type => "text", is_nullable => 0 },
  "active",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</numerical_id>

=back

=cut

__PACKAGE__->set_primary_key("numerical_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_species>

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_species", ["id"]);

=head1 RELATIONS

=head2 assemblies

Type: has_many

Related object: L<WGE::Model::Schema::Result::Assembly>

=cut

__PACKAGE__->has_many(
  "assemblies",
  "WGE::Model::Schema::Result::Assembly",
  { "foreign.species_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 chromosomes

Type: has_many

Related object: L<WGE::Model::Schema::Result::Chromosome>

=cut

__PACKAGE__->has_many(
  "chromosomes",
  "WGE::Model::Schema::Result::Chromosome",
  { "foreign.species_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 design_attempts

Type: has_many

Related object: L<WGE::Model::Schema::Result::DesignAttempt>

=cut

__PACKAGE__->has_many(
  "design_attempts",
  "WGE::Model::Schema::Result::DesignAttempt",
  { "foreign.species_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 designs

Type: has_many

Related object: L<WGE::Model::Schema::Result::Design>

=cut

__PACKAGE__->has_many(
  "designs",
  "WGE::Model::Schema::Result::Design",
  { "foreign.species_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genes

Type: has_many

Related object: L<WGE::Model::Schema::Result::Gene>

=cut

__PACKAGE__->has_many(
  "genes",
  "WGE::Model::Schema::Result::Gene",
  { "foreign.species_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 species_default_assembly

Type: might_have

Related object: L<WGE::Model::Schema::Result::SpeciesDefaultAssembly>

=cut

__PACKAGE__->might_have(
  "species_default_assembly",
  "WGE::Model::Schema::Result::SpeciesDefaultAssembly",
  { "foreign.species_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-09-30 10:51:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lOgTfmyS0AWTk6DblJFzBg


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->might_have(
  "default_assembly",
  "WGE::Model::Schema::Result::SpeciesDefaultAssembly",
  { "foreign.species_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

sub as_hash {
  my ( $self ) = @_;

  return {
    id           => $self->id,
    numerical_id => $self->numerical_id,
    display_name => $self->display_name,
    active       => $self->active,
  };
}

sub name {
  my ( $self ) = @_;

  return $self->id;
}

#extract assembly from display name
sub assembly {
  my ( $self ) = @_;

  my ( $assembly ) = $self->display_name =~ /.*\((.*)\)/;

  return $assembly;
}

sub check_assembly_belongs {
    my ( $self, $assembly ) = @_;

    unless ( $self->assemblies->find({ id => $assembly }) ) {
        require LIMS2::Exception::InvalidState;
        LIMS2::Exception::InvalidState->throw(
            "Assembly $assembly does not belong to species " . $self->id
        );
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;
1;
