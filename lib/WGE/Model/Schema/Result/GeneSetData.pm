package WGE::Model::Schema::Result::GeneSetData;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::GeneSetData::VERSION = '0.124';
}
## use critic

use strict;
use warnings;

=head1 NAME

WGE::Model::Schema::Result::GeneSetData

=head1 SYNOPSIS

This is a template for a table which contains genomic structure data.
Implementations can be created and referenced in the GeneSet table.

=cut

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

__PACKAGE__->table('GeneSetData');

__PACKAGE__->add_columns(
  id              => { data_type => "text", is_nullable => 0 },
  feature_type_id => { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  chr_name        => { data_type => "text", is_nullable => 0 },
  chr_start       => { data_type => "integer", is_nullable => 0 },
  chr_end         => { data_type => "integer", is_nullable => 0 },
  strand          => { data_type => "integer", is_nullable => 0 },
  rank            => { data_type => "integer", is_nullable => 0 },
  name            => { data_type => "text", is_nullable => 1 },
  parent_id       => { data_type => "text", is_foreign_key => 1, is_nullable => 1 },
  gene_type       => { data_type => "text", is_nullable => 1 },
  gene_id         => { data_type => "text", is_nullable => 1 },
  transcript_id   => { data_type => "text", is_nullable => 1 },
  protein_id      => { data_type => "text", is_nullable => 1 },
  biotype         => { data_type => "text", is_nullable => 1 },
  description     => { data_type => "text", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 feature_type

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::FeatureType>

=cut

__PACKAGE__->belongs_to(
  "feature_type",
  "WGE::Model::Schema::Result::FeatureType",
  { id => "feature_type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 parent

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::GeneSetData>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "WGE::Model::Schema::Result::GeneSetData",
  { id => "parent_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 children

Type: has_many

Related object: L<WGE::Model::Schema::Result::GeneSetData>

=cut

__PACKAGE__->has_many(
  "children",
  "WGE::Model::Schema::Result::GeneSetData",
  { "foreign.parent_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->meta->make_immutable;
1;

