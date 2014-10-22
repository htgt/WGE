use utf8;
package WGE::Model::Schema::Result::CrisprPair;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::CrisprPair::VERSION = '0.051';
}
## use critic


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


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2014-04-07 13:53:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BOB/yT8Z3MFYX7bL/aUZOg

#TODO: integrate log into schema instead of result
use Try::Tiny;
use JSON qw( encode_json );
with qw( MooseX::Log::Log4perl );

use YAML::Any qw( Load );

sub as_hash {
  my ( $self, $options ) = @_;

  my $data = {
    left_crispr        => $self->left->as_hash,
    right_crispr       => $self->right->as_hash,
    spacer             => $self->spacer,
    species_id         => $self->species_id,
    off_target_summary => $self->off_target_summary,
    status_id          => $self->status_id,
    id                 => $self->id,
  };

  #if they want off targets return them as a list of hashes
  if ( $options->{with_offs} ) {
    $data->{off_targets} = $self->off_targets;
  }

  #optional because otherwise if you have a lot
  #each one will do a new db call with a join to get the status
  if ( $options->{get_status} ) {
    $data->{status} = $self->status->status;
  }

  # Add db_data to hash in the same way as FindPairs::find_pairs
  if ( $options->{db_data} ) {
    my $db_data = {
      status_id => $self->status_id,
      status    => $self->status->status,
      off_target_summary => $self->off_target_summary,
    };
    $data->{db_data} = $db_data;
    foreach my $dir (qw(left_crispr right_crispr)){
      #
      # this is temp -- we should switch db to store in array
      #
      if ( $data->{$dir}->{off_target_summary} ) {
        my @sum;
        #convert hash to array
        my $summary = Load( $data->{$dir}->{off_target_summary} );

        while ( my ( $k, $v ) = each %{ $summary } ) {
            $sum[$k] = $v;
        }

        $data->{$dir}->{off_target_summary_arr} = \@sum;
      }
    }
  }

  return $data;
}

sub species {
  my $self = shift;

  return $self->result_source->schema->resultset('Species')->find(
      { numerical_id => $self->species_id }
  );
}

sub get_species {
  my $self = shift;

  return $self->species->id;
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
      my $data = {
        left_crispr  => $left->as_hash,
        right_crispr => $right->as_hash
      };

      $data->{spacer} = ($data->{right_crispr}{chr_start} - $data->{left_crispr}{chr_end}) - 1;

      push @pairs, $data;
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

    $self->log->debug('Calculating paired off targets');

    #the max distance between paired off targets
    #default off target distance is 1k
    $distance //= 1000;
    my $total;
    my $error = 0;

    try {
      my ( $offs, $closest ) = $self->_get_all_paired_off_targets( $distance );

      #if its undefined it means the crisprs were bad, so don't do anything
      return unless defined $offs;

      #there could have been no paired off targets, so we won't get a closest
      $closest = (defined $closest) ? $closest->{spacer} : "None";

      $total = scalar( @{ $offs } ) / 2;

      #convert hash to json string
      my $summary = encode_json {
        total_pairs  => $total,
        max_distance => $distance,
        closest      => $closest,
      };

      $self->update(
        {
          off_target_ids     => $offs,
          off_target_summary => $summary,
          status_id          => 5, #complete
        }
      );
    }
    catch {
      #could do with some logging here
      $error = 1;
      $self->update( { status_id => -1 } );
      $self->log->warn( $_ );
    };

    #should return the error or something really
    die "Calculating off targets failed!" if $error;

    #return the number of pairs
    return $total;
}

sub _get_all_paired_off_targets {
  my ( $self, $distance ) = @_;

  #see if anything is missing#
  #this will also set the status to -2 if the pair has a bad crispr
  if ( my @missing = $self->_data_missing ) {
    die "Can't calculate off targets as data is missing for crisprs:" . join( ", ", @missing );
  }

  #make sure this is a valid pair that has all the required off target data
  return if $self->status_id == -2;

  #change status to calculating off targets
  $self->update( { status_id => 4 } );

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

      #don't include this pair in the closest comparison or we'll always get it
      next if $pair->{left_crispr}{id} eq $self->left_id
          and $pair->{right_crispr}{id} eq $self->right_id;

      if ( ! defined $closest || $closest->{spacer} > $pair->{spacer} ) {
        $closest = $pair;
      }
    }
  }

  die "Uneven number of pair ids!" unless @all_offs % 2 == 0;

  return \@all_offs, $closest;
}

=head1 _data_missing

Returns false if this crispr is already complete, and a list of crisprs
in need of off target data if any are missing.

Will update the status of this pair to -2 (bad crispr) if a bad crispr
is tied to this pair, or to 1 (pending) if there is data missing.
It is expected that after calling this method you will be updating this crispr,
or it will be left pending forever

Optionally takes a resultset of crisprs to check. This is
for the case where you have already created the crispr resultset
for this pair, so there's no point retrieving the crispr data again

=cut
sub _data_missing {
  my ( $self, $crisprs ) = @_;
  #crisprs resultset must have total_offs selected (see below)

  #this status has already been calculated, so just return it as is
  return if $self->status_id == -2;

  #if we were provided with crisprs make sure its an arrayref with 2 entries
  if ( defined $crisprs && ref $crisprs eq 'ARRAY' && @{ $crisprs } == 2 ) {
    $self->log->warn( "2 crisprs provided, using those" );
  }
  else{
    $self->log->warn( "No crisprs provided, searching crispr table" );

    my @rows = $self->result_source->schema->resultset('Crispr')->search(
      {
        id         => { -IN => [ $self->left_id, $self->right_id ] },
        species_id => $self->species_id
      },
      {
        select => [
          'id',
          'off_target_summary',
          { array_length => [ 'off_target_ids', 1 ], -as => 'total_offs' }
        ]
      }
    );

    $crisprs = \@rows;

    die "Couldn't find crisprs!" unless defined $crisprs;
  }

  #we allow an arrayref or a resultset in $crisprs
  my @needs_ots_data;
  for my $crispr ( @{ $crisprs } ) {
    #if a crispr has a summary but no off targets it means its a bad
    #crispr with too many off targets. We therefore set the pair status to bad,
    #as we can't calculate off targets for it
    if ( defined $crispr->get_column( 'off_target_summary' ) ) {
      if ( ! defined $crispr->get_column( 'total_offs' )) {
        #this means one of the crisprs in this pair is bad;
        #update accordingly and return false as this pair is 'complete'
        $self->update( { status_id => -2 } );
        return;
      }
    }
    else {
      #this means a crispr in this pair doesn't have ots data
      push @needs_ots_data, $crispr->id;
    }
  }

  #change status to 'pending' as we expect the user to now do something with it
  $self->update( { status_id => 1 } );

  #if any crisprs need off target data return them
  return @needs_ots_data;
}

sub reset_status {
  shift->update( { status_id => 0 } );
  return;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
sub link_to_user_id{
    my ($self, $user_id) = @_;
    my $schema = $self->result_source->schema;
    my $species = $self->get_species;
    my $linker_table = "UserCrisprPairs".$species;

    my $link = $schema->resultset($linker_table)->new({ crispr_pair_id => $self->id, user_id => $user_id });
    $link->insert;

    return;
}

sub remove_link_to_user_id{
    my ($self, $user_id) = @_;
    my $schema = $self->result_source->schema;
    my $species = $self->get_species;
    my $linker_table = "UserCrisprPairs".$species;

    my $link = $schema->resultset($linker_table)->find({ crispr_pair_id => $self->id, user_id => $user_id });
    $link->delete;

    return;
}

__PACKAGE__->meta->make_immutable;
1;
