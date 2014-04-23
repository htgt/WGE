use utf8;
package WGE::Model::Schema::Result::Crispr;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::Crispr::VERSION = '0.013';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Crispr

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

=head1 TABLE: C<crisprs>

=cut

__PACKAGE__->table("crisprs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'crisprs_id_seq'

=head2 chr_name

  data_type: 'text'
  is_nullable: 0

=head2 chr_start

  data_type: 'integer'
  is_nullable: 0

=head2 seq

  data_type: 'text'
  is_nullable: 0

=head2 pam_right

  data_type: 'boolean'
  is_nullable: 0

=head2 species_id

  data_type: 'integer'
  is_nullable: 0

=head2 off_target_ids

  data_type: 'integer[]'
  is_nullable: 1

=head2 off_target_summary

  data_type: 'text'
  is_nullable: 1

=head2 exonic

  data_type: 'boolean'
  is_nullable: 1

=head2 genic

  data_type: 'boolean'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "crisprs_id_seq",
  },
  "chr_name",
  { data_type => "text", is_nullable => 0 },
  "chr_start",
  { data_type => "integer", is_nullable => 0 },
  "seq",
  { data_type => "text", is_nullable => 0 },
  "pam_right",
  { data_type => "boolean", is_nullable => 0 },
  "species_id",
  { data_type => "integer", is_nullable => 0 },
  "off_target_ids",
  { data_type => "integer[]", is_nullable => 1 },
  "off_target_summary",
  { data_type => "text", is_nullable => 1 },
  "exonic",
  { data_type => "boolean", is_nullable => 1 },
  "genic",
  { data_type => "boolean", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 crispr_pairs_left

Type: has_many

Related object: L<WGE::Model::Schema::Result::CrisprPair>

=cut

__PACKAGE__->has_many(
  "crispr_pairs_left",
  "WGE::Model::Schema::Result::CrisprPair",
  { "foreign.left_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 crispr_pairs_rights

Type: has_many

Related object: L<WGE::Model::Schema::Result::CrisprPair>

=cut

__PACKAGE__->has_many(
  "crispr_pairs_rights",
  "WGE::Model::Schema::Result::CrisprPair",
  { "foreign.right_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-04-14 10:58:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XZrdxdr4Rn6M/6RCR93lLQ


__PACKAGE__->set_primary_key('id');

with 'WGE::Util::CrisprRole';

sub as_hash {
  my ( $self, $options ) = @_;

  #should just do a map on $self->columns...
  my $data = {
    id                 => $self->id,
    chr_name           => $self->chr_name,
    chr_start          => $self->chr_start,
    chr_end            => $self->chr_end,
    seq                => $self->seq,
    species_id         => $self->species_id,
    pam_right          => $self->pam_right,
    off_target_summary => $self->off_target_summary,
  };

  #if they want off targets return them as a list of hashes
  if ( $options->{with_offs} ) {
    #pass options along to as hash 
    $data->{off_targets} = [ map { $_->as_hash( $options ) } $self->off_targets ];
  }

  return $data;
}

sub pairs {
  my $self = shift;

  return ($self->pam_right) ? $self->crispr_pairs_right : $self->crispr_pairs_left;
}

sub off_targets {
  my $self = shift;

  return $self->result_source->schema->resultset('CrisprOffTargets')->search(
    {},
    { bind => [ "{" . $self->id . "}", $self->species_id, $self->species_id ] }
  );
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
sub link_to_user_id{
    my ($self, $user_id) = @_;
    my $schema = $self->result_source->schema;
    my $species = $schema->resultset('Species')->find({ numerical_id => $self->species_id });
    my $linker_table = "UserCrisprs".$species->id;

    my $link = $schema->resultset($linker_table)->new({ crispr_id => $self->id, user_id => $user_id });
    $link->insert;

    return;
}

sub remove_link_to_user_id{
    my ($self, $user_id) = @_;
    my $schema = $self->result_source->schema;
    my $species = $schema->resultset('Species')->find({ numerical_id => $self->species_id });
    my $linker_table = "UserCrisprs".$species->id;

    my $link = $schema->resultset($linker_table)->find({ crispr_id => $self->id, user_id => $user_id });
    $link->delete;
    
    return; 
}
__PACKAGE__->meta->make_immutable;
1;
