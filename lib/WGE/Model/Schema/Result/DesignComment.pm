use utf8;
package WGE::Model::Schema::Result::DesignComment;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::DesignComment::VERSION = '0.126';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::DesignComment

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

=head1 TABLE: C<design_comments>

=cut

__PACKAGE__->table("design_comments");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'design_comments_id_seq'

=head2 design_comment_category_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 design_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 comment_text

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 is_public

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 created_by

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "design_comments_id_seq",
  },
  "design_comment_category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "design_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "comment_text",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "is_public",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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
  { id => "created_by" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 design

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Design>

=cut

__PACKAGE__->belongs_to(
  "design",
  "WGE::Model::Schema::Result::Design",
  { id => "design_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 design_comment_category

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::DesignCommentCategory>

=cut

__PACKAGE__->belongs_to(
  "design_comment_category",
  "WGE::Model::Schema::Result::DesignCommentCategory",
  { id => "design_comment_category_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-01-23 10:25:34
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IFSyYBmmrv21bjhsbAf5bA

sub as_hash {
    my $self = shift;

    return {
        id           => $self->id,
        category     => $self->design_comment_category->name,
        comment_text => $self->comment_text,
        is_public    => $self->is_public,
        created_at   => $self->created_at->iso8601,
        created_by   => $self->created_by->name
    }
}

__PACKAGE__->meta->make_immutable;
1;
