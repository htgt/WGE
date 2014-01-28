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


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-01-23 13:58:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:frJ+3S6bI8G0wy8BJUenaQ

use WGE::Util::FindPairs;

sub crisprs {
  my ( $self ) = @_;

  #get the species id with just 1 db call
  my $species = $self->result_source->schema->resultset('Gene')->find(
    { id => $self->gene_id },
    { prefetch => 'species' }
  )->species;

  #find all crisprs for this exon
  #maybe we should change CrisprByExon to not take a list
  return $self->result_source->schema->resultset('CrisprByExon')->search(
    {},
    { bind => [ '{'.$self->ensembl_exon_id.'}', $species->numerical_id ] }
  );
}

sub pairs {
  my $self = shift;

  #get all the crisprs, then identify all the pairs
  my @crisprs = $self->crisprs;

  my $pair_finder = WGE::Util::FindPairs->new;
  #check the list of crisprs against itself for pairs
  my $pairs = $pair_finder->find_pairs( \@crisprs, \@crisprs );

  return wantarray ? @{ $pairs } : $pairs;

}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
