use utf8;
package WGE::Model::Schema::Result::LibraryDesignJob;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::LibraryDesignJob

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

=head1 TABLE: C<library_design_jobs>

=cut

__PACKAGE__->table("library_design_jobs");

=head1 ACCESSORS

=head2 id

  data_type: 'text'
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 params

  data_type: 'json'
  is_nullable: 0

=head2 target_region_count

  data_type: 'integer'
  is_nullable: 0

=head2 library_design_stage_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 1

=head2 progress_percent

  data_type: 'integer'
  is_nullable: 0

=head2 complete

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 error

  data_type: 'text'
  is_nullable: 1

=head2 created_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 created_by_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 last_modified

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 warning

  data_type: 'text'
  is_nullable: 1

=head2 results_file

  data_type: 'text'
  is_nullable: 1

=head2 info

  data_type: 'text'
  is_nullable: 1

=head2 input_file

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "text", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "params",
  { data_type => "json", is_nullable => 0 },
  "target_region_count",
  { data_type => "integer", is_nullable => 0 },
  "library_design_stage_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 1 },
  "progress_percent",
  { data_type => "integer", is_nullable => 0 },
  "complete",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "error",
  { data_type => "text", is_nullable => 1 },
  "created_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "created_by_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "last_modified",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "warning",
  { data_type => "text", is_nullable => 1 },
  "results_file",
  { data_type => "text", is_nullable => 1 },
  "info",
  { data_type => "text", is_nullable => 1 },
  "input_file",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 created_by

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "created_by",
  "WGE::Model::Schema::Result::User",
  { id => "created_by_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 library_design_stage

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::LibraryDesignStage>

=cut

__PACKAGE__->belongs_to(
  "library_design_stage",
  "WGE::Model::Schema::Result::LibraryDesignStage",
  { id => "library_design_stage_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2016-08-22 14:28:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oZEG8Ri99GFFgDgJo2QHTw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
use JSON;

__PACKAGE__->inflate_column( params => {
    inflate => sub{ from_json( +shift ) },
    deflate => sub{
      my $json = shift;
      ref $json ? to_json($json) : $json;
    },
});

__PACKAGE__->meta->make_immutable;
1;
