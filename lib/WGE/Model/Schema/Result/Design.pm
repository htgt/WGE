use utf8;
package WGE::Model::Schema::Result::Design;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::Design::VERSION = '0.121';
}
## use critic


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::Design

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

=head1 TABLE: C<designs>

=cut

__PACKAGE__->table("designs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'designs_id_seq'

=head2 species_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 created_by

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 design_type_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 phase

  data_type: 'integer'
  is_nullable: 1

=head2 validated_by_annotation

  data_type: 'text'
  is_nullable: 0

=head2 target_transcript

  data_type: 'text'
  is_nullable: 1

=head2 design_parameters

  data_type: 'json'
  is_nullable: 1

=head2 cassette_first

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "designs_id_seq",
  },
  "species_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "design_type_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "phase",
  { data_type => "integer", is_nullable => 1 },
  "validated_by_annotation",
  { data_type => "text", is_nullable => 0 },
  "target_transcript",
  { data_type => "text", is_nullable => 1 },
  "design_parameters",
  { data_type => "json", is_nullable => 1 },
  "cassette_first",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
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

=head2 design_comments

Type: has_many

Related object: L<WGE::Model::Schema::Result::DesignComment>

=cut

__PACKAGE__->has_many(
  "design_comments",
  "WGE::Model::Schema::Result::DesignComment",
  { "foreign.design_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 design_oligos

Type: has_many

Related object: L<WGE::Model::Schema::Result::DesignOligo>

=cut

__PACKAGE__->has_many(
  "design_oligos",
  "WGE::Model::Schema::Result::DesignOligo",
  { "foreign.design_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 design_type

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::DesignType>

=cut

__PACKAGE__->belongs_to(
  "design_type",
  "WGE::Model::Schema::Result::DesignType",
  { id => "design_type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 gene_designs

Type: has_many

Related object: L<WGE::Model::Schema::Result::GeneDesign>

=cut

__PACKAGE__->has_many(
  "gene_designs",
  "WGE::Model::Schema::Result::GeneDesign",
  { "foreign.design_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genotyping_primers

Type: has_many

Related object: L<WGE::Model::Schema::Result::GenotypingPrimer>

=cut

__PACKAGE__->has_many(
  "genotyping_primers",
  "WGE::Model::Schema::Result::GenotypingPrimer",
  { "foreign.design_id" => "self.id" },
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


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2017-06-20 16:59:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2y3EysaQ6HjC4F9h/t5Ycw


# You can replace this text with custom code or comments, and it will be preserved on regeneration

# Add some relationship names which do not follow the usual conventions
__PACKAGE__->has_many(
  "genes",
  "WGE::Model::Schema::Result::GeneDesign",
  { "foreign.design_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "oligos",
  "WGE::Model::Schema::Result::DesignOligo",
  { "foreign.design_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "comments",
  "WGE::Model::Schema::Result::DesignComment",
  { "foreign.design_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

use List::MoreUtils qw( uniq );

sub as_hash {
    my ( $self, $suppress_relations ) = @_;

    # updates design object with latest information from database
    # if not done then the created_at value which can default to the current
    # timestamp does not seem to be set and a error is thrown
    $self->discard_changes;

    my %h = (
        id                      => $self->id,
        name                    => $self->name,
        type                    => $self->design_type_id,
        created_at              => $self->created_at->iso8601,
        created_by              => $self->created_by->name,
        phase                   => $self->phase,
        validated_by_annotation => $self->validated_by_annotation,
        target_transcript       => $self->target_transcript,
        species                 => $self->species_id,
        assigned_genes          => [ map { $_->gene_id } $self->genes ],
        cassette_first          => $self->cassette_first,
    );

    if ( ! $suppress_relations ) {
        my $strand = $self->strand;
        $h{strand}             = $strand;
        my $oligos = $self->_sort_oligos;
        $h{comments}           = [ map { $_->as_hash } $self->design_comments ];
        $h{oligos}             = $oligos;
        $h{assembly}           = $oligos->[0]{locus}{assembly};
        $h{oligos_fasta}       = $self->_oligos_fasta( $oligos );
        $h{oligo_order_seqs}   = $self->oligo_order_seqs( $strand );
        $h{genotyping_primers} = [ sort { $a->{type} cmp $b->{type} } map { $_->as_hash } $self->genotyping_primers ];
    }

    return \%h;
}

sub _sort_oligos {
    my $self = shift;

    my @oligos = map { $_->[0] }
        sort { $a->[1] <=> $b->[1] }
            map { [ $_, $_->{locus} ? $_->{locus}{chr_start} : -1 ] }
                map { $_->as_hash } $self->oligos;

    return \@oligos;
}

sub _oligos_fasta {
    my ( $self, $oligos ) = @_;

    return unless @{$oligos};

    my $strand = $oligos->[0]{locus}{chr_strand};
    return unless $strand;

    require Bio::Seq;
    require Bio::SeqIO;
    require IO::String;

    my $fasta;
    my $seq_io = Bio::SeqIO->new( -format => 'fasta', -fh => IO::String->new( $fasta ) );

    my $seq = Bio::Seq->new( -display_id => 'design_' . $self->id,
                             -alphabet   => 'dna',
                             -seq        => join '', map { $_->{seq} } @{ $oligos } );

    $seq_io->write_seq( $strand == 1 ? $seq : $seq->revcom );

    return $fasta;
}

=head2 design_attempt

Find the design attempt record linked to this design and return it.
Returns undef if no design attempt record found.

=cut
sub design_attempt {
    my $self = shift;

    my $schema = $self->result_source->schema;
    my $design_attempts = $schema->resultset('DesignAttempt')->search_literal(
        '? = ANY ( design_ids )', $self->id
    );

    return $design_attempts->first;
}

sub oligo_order_seqs {
    my ( $self, $strand ) = @_;
    $strand //= $self->strand;
    my %oligo_order_seqs;

    my @oligos = $self->oligos;
    for my $oligo ( @oligos ) {
        my $type = $oligo->design_oligo_type_id;
        $oligo_order_seqs{ $type } = $oligo->oligo_order_seq( $strand, $self->design_type_id );
    }

    return \%oligo_order_seqs;
}

sub strand {
    my ( $self ) = @_;

    my @strands = uniq map { $_->{locus}{chr_strand} } map { $_->as_hash } $self->oligos;
    die (
        'Design ' . $self->design->id . ' oligos have inconsistent strands'
    ) unless @strands == 1;

    return $strands[0];
}

__PACKAGE__->meta->make_immutable;
1;
