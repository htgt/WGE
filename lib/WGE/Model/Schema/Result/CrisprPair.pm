use utf8;
package WGE::Model::Schema::Result::CrisprPair;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WGE::Model::Schema::Result::CrisprPair

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

=head1 TABLE: C<crispr_pairs>

=cut

__PACKAGE__->table("crispr_pairs");

=head1 ACCESSORS

=head2 left_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 right_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 spacer

  data_type: 'integer'
  is_nullable: 0

=head2 off_target_ids

  data_type: 'integer[]'
  is_nullable: 1

=head2 status_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 1

=head2 species_id

  data_type: 'integer'
  is_nullable: 0

=head2 off_target_summary

  data_type: 'text'
  is_nullable: 1

=head2 last_modified

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 id

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "left_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "right_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "spacer",
  { data_type => "integer", is_nullable => 0 },
  "off_target_ids",
  { data_type => "integer[]", is_nullable => 1 },
  "status_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 1,
  },
  "species_id",
  { data_type => "integer", is_nullable => 0 },
  "off_target_summary",
  { data_type => "text", is_nullable => 1 },
  "last_modified",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "id",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</left_id>

=item * L</right_id>

=back

=cut

__PACKAGE__->set_primary_key("left_id", "right_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_pair_id>

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_pair_id", ["id"]);

=head1 RELATIONS

=head2 left

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Crispr>

=cut

__PACKAGE__->belongs_to(
  "left",
  "WGE::Model::Schema::Result::Crispr",
  { id => "left_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 right

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::Crispr>

=cut

__PACKAGE__->belongs_to(
  "right",
  "WGE::Model::Schema::Result::Crispr",
  { id => "right_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 status

Type: belongs_to

Related object: L<WGE::Model::Schema::Result::CrisprPairStatus>

=cut

__PACKAGE__->belongs_to(
  "status",
  "WGE::Model::Schema::Result::CrisprPairStatus",
  { id => "status_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-02-18 14:32:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hd1bRXCDGxXNRC0d4BJnlA

use Try::Tiny;

sub as_hash {
  my $self = shift;

  return {
    left_crispr        => $self->left->as_hash,
    right_crispr       => $self->right->as_hash,
    spacer             => $self->spacer,
    species_id         => $self->species_id,
    off_target_ids     => $self->off_target_ids,
    off_target_summary => $self->off_target_summary,
  };
}

=head1

Return all paired off targets associated with this pair as a list of hashes

=cut
sub off_targets {
  my $self = shift;

  my @pairs;
  if ( defined $self->off_target_ids ) {
    #this resultset returns a list, where every even element is the left element
    #in a paired off target, and every odd element is the right.
    my @paired_offs = $self->result_source->schema->resultset('PairOffTargets')->search(
        {},
        { bind => [ $self->left_id, $self->right_id, $self->species_id, $self->species_id ] }
    );

    # get 2 entries at a time from the list
    while ( my ($left, $right) = splice( @paired_offs, 0, 2 ) ) {
      push @pairs, { left_crispr => $left, right_crispr => $right };
    }
  }

  return wantarray ? @pairs : \@pairs;
}

=head1

This method will populate off_target_ids and off_target_summary fields
(assuming both crisprs have off target data)
takes optional parameter of the distance between off targets

=cut
sub calculate_off_targets {
    my ( $self, $distance ) = @_;

    #the max distance between paired off targets
    #default off target distance is 1k
    $distance //= 1000;
    my $total;

    try {
      my ( $offs, $closest ) = $self->_get_all_paired_off_targets( $distance );

      #if its undefined it means the crisprs were bad, so don't do anything
      return unless defined $offs;

      #there could have been no paired off targets, so we won't get a closest
      $closest = (defined $closest) ? $closest->{spacer} : "";

      $total = scalar( @{ $offs } ) / 2;
      my $summary = qq/{"total pairs:"$total", "max_distance": "$distance" "closest": "$closest"}/;

      $self->update(
        {
          off_target_ids     => $offs,
          off_target_summary => $summary,
          status             => 5, #complete
        }
      );
    }
    catch {
      #could do with some logging here
      $self->update( { status => -1 } );
      print $_ . "\n";
    };

    #return the number of pairs
    return $total;
}

sub _get_all_paired_off_targets {
  my ( $self, $distance ) = @_;

  #if this returned false we don't have all the data we need, so bail
  return unless $self->check_crisprs;

  #get all off targets
  my @crisprs = $self->result_source->schema->resultset('CrisprOffTargets')->search(
      {},
      { 
        bind => [ 
                  '{' . $self->left_id . ',' . $self->right_id . '}', 
                  $self->species_id, 
                  $self->species_id  
                ] 
      }
  );

  #group the crisprs by chr_name for quicker comparison
  #i couldn't get the sql to return in a nice way so i just process here
  my %data;
  for my $crispr ( @crisprs ) {
      push @{ $data{ $crispr->chr_name } }, $crispr;
  }

  #get instance of FindPairs with off target settings
  my $pair_finder = WGE::Util::FindPairs->new(
    max_spacer  => $distance,
    include_h2h => 1
  );

  # find all off targets for crispr off targets in each chromosome
  my ( @all_offs, $closest );
  while ( my ( $chr_name, $crisprs ) = each %data ) {
    my $pairs =  $pair_finder->find_pairs( $crisprs, $crisprs );

    #throw all the ids onto one array,
    #when processing you will take 2 off at a time.
    for my $pair ( @{ $pairs } ) {
      push @all_offs, $pair->{left_crispr}{id}, $pair->{right_crispr}{id};

      if ( ! defined $closest || $closest->{spacer} > $pair->{spacer} ) {
        $closest = $pair;
      }
    }
  }

  die "Uneven number of pair ids!" unless @all_offs % 2 == 0;

  return \@all_offs, $closest;
}

=head1 

This method checks the off target data of the crisprs attached
to this pair, and updates the status accordingly.

=cut
sub check_crisprs {
  my ( $self ) = @_;

  #make sure both pairs have off targets
  my @crisprs = $self->result_source->schema->resultset('Crispr')->search(
    { 
      id => { -IN => [ $self->left_id, $self->right_id ] }  
    },
    { 
      select => [
        'id',
        'off_target_summary',
        { array_length => [ 'off_target_ids', 1 ], -as => 'total_offs' }
      ]
    }
  );

  my $status = 4; #calculating off targets status
  for my $crispr ( @crisprs ) {
    #if a crispr has a summary but no off targets it means its a bad
    #crispr with too many off targets. We therefore set the pair status to bad,
    #as we can't calculate off targets for it
    if ( defined $crispr->get_column( 'off_target_summary' ) ) {
      if ( ! defined $crispr->get_column( 'total_offs' )) {
        $status = -2;
        last;
      }
    }
    else {
      $status = -3; #this means a crispr in this pair doesn't have ots data
    }
  }

  $self->update( { status => $status } );

  #true if everything is good, false if error of some kind
  return $status > 0; 
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
