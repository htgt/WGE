use utf8;
package WGE::Model::Schema::Result::Exon;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Exon

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

=head1 TABLE: C<exons>

=cut

__PACKAGE__->table("exons");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'exons_id_seq'

=head2 ensembl_exon_id

  data_type: 'text'
  is_nullable: 0

=head2 gene_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 chr_start

  data_type: 'integer'
  is_nullable: 0

=head2 chr_end

  data_type: 'integer'
  is_nullable: 0

=head2 chr_name

  data_type: 'text'
  is_nullable: 0

=head2 rank

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "exons_id_seq",
  },
  "ensembl_exon_id",
  { data_type => "text", is_nullable => 0 },
  "gene_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "chr_start",
  { data_type => "integer", is_nullable => 0 },
  "chr_end",
  { data_type => "integer", is_nullable => 0 },
  "chr_name",
  { data_type => "text", is_nullable => 0 },
  "rank",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<exons_ensembl_exon_id_key>

=over 4

=item * L</ensembl_exon_id>

=back

=cut

__PACKAGE__->add_unique_constraint("exons_ensembl_exon_id_key", ["ensembl_exon_id"]);

=head1 RELATIONS

=head2 gene

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Gene>

=cut

__PACKAGE__->belongs_to(
  "gene",
  "WGE::Model::Schema::Result::Gene",
  { id => "gene_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2013-11-27 16:26:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uMBFi2/DIBNQ2tnkYI/d7A

sub crisprs {
    my ( $self, $options ) = @_;

    #if the user didn't specify an order, we should provide one
    unless ( defined $options->{order_by} ) {
      $options->{order_by} = { -asc => 'chr_start' };
    }

    #use custom resultset method to retrieve crisprs
    return $self->result_source->schema->resultset('Crispr')->search_by_loci( $self, $options );
}

sub pairs {
  my $self = shift;

  #should add a prefetch
  return $self->crisprs->all_pairs;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
