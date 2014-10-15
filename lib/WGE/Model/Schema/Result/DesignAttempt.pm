use utf8;
package WGE::Model::Schema::Result::DesignAttempt;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::DesignAttempt::VERSION = '0.047';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::DesignAttempt

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

=head1 TABLE: C<design_attempts>

=cut

__PACKAGE__->table("design_attempts");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'design_attempts_id_seq'

=head2 design_parameters

  data_type: 'json'
  is_nullable: 1

=head2 gene_id

  data_type: 'text'
  is_nullable: 1

=head2 status

  data_type: 'text'
  is_nullable: 1

=head2 fail

  data_type: 'json'
  is_nullable: 1

=head2 error

  data_type: 'text'
  is_nullable: 1

=head2 design_ids

  data_type: 'integer[]'
  is_nullable: 1

=head2 species_id

  data_type: 'text'
  is_foreign_key: 1
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

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 candidate_oligos

  data_type: 'json'
  is_nullable: 1

=head2 candidate_regions

  data_type: 'json'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "design_attempts_id_seq",
  },
  "design_parameters",
  { data_type => "json", is_nullable => 1 },
  "gene_id",
  { data_type => "text", is_nullable => 1 },
  "status",
  { data_type => "text", is_nullable => 1 },
  "fail",
  { data_type => "json", is_nullable => 1 },
  "error",
  { data_type => "text", is_nullable => 1 },
  "design_ids",
  { data_type => "integer[]", is_nullable => 1 },
  "species_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "candidate_oligos",
  { data_type => "json", is_nullable => 1 },
  "candidate_regions",
  { data_type => "json", is_nullable => 1 },
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


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-07-11 13:28:31
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:eAZCnTmQv5gLRBDoUf+oPA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
sub as_hash {
    my ( $self, $opts ) = @_;

    # updates design object with latest information from database
    # if not done then the created_at value which can default to the current
    # timestamp does not seem to be set and a error is thrown
    $self->discard_changes;

    use JSON;
    use Try::Tiny;

    my $json = JSON->new;
    my ( $design_params, $fail_reason );
    if ( $opts->{pretty_print_json} ) {
        $design_params
            = $self->design_parameters
            ? try { $json->pretty->encode( $json->decode( $self->design_parameters ) ) }
            : '';
        $fail_reason
            = $self->fail ? try { $json->pretty->encode( $json->decode( $self->fail ) ) } : '';
    }
    elsif ( $opts->{json_as_hash} ) {
        $design_params
            = $self->design_parameters ? try { $json->decode( $self->design_parameters ) } : undef;
        $fail_reason = $self->fail ? try { $json->decode( $self->fail ) } : undef;
    }
    else {
        $design_params = $self->design_parameters;
        $fail_reason = $self->fail;
    }
    my $candidate_oligos  = $self->candidate_oligos  ? try { $json->decode( $self->candidate_oligos ) }  : undef;
    my $candidate_regions = $self->candidate_regions ? try { $json->decode( $self->candidate_regions ) } : undef;

    my %h = (
        id                => $self->id,
        design_parameters => $design_params,
        gene_id           => $self->gene_id,
        status            => $self->status,
        fail              => $fail_reason,
        error             => $self->error,
        design_ids        => $self->design_ids,
        species           => $self->species_id,
        created_at        => $self->created_at->iso8601,
        created_by        => $self->created_by->name,
        comment           => $self->comment,
        candidate_oligos  => $candidate_oligos,
        candidate_regions => $candidate_regions,
    );

    return \%h;
}

__PACKAGE__->meta->make_immutable;
1;
