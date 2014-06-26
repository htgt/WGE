package WGE::Util::FindPairs;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::FindPairs::VERSION = '0.024';
}
## use critic


use strict;
use warnings;

use feature qw( say );

use Moose;

has min_spacer => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
    default  => '-10'
);

# you'll want to set this to around 1000 to find offs
has max_spacer => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
    default  => '30'
);

#specify whether or not head to head
#is a valid pair orientation.
#mainly this is used for finding off targets
has include_h2h => (
    is       => 'rw',
    isa      => 'Bool',
    default  => 0
);

#an optional schema can be provided if
#the user wants db data with their pairs
has schema => (
    is       => 'ro',
    isa      => 'WGE::Model::Schema',
    required => 0
);

has log => (
    is         => 'rw',
    isa        => 'Log::Log4perl::Logger',
    lazy_build => 1
);

sub _build_log {
    require Log::Log4perl;
    return Log::Log4perl->get_logger("WGE");
}

# Faster pair finding for pairs in a large region, e.g. for genoverse browser
sub window_find_pairs{
    my ($self, $start, $end, $pairs, $options) = @_;
    my $window_size = 400;
    my $max_pair_span = 23 + $self->max_spacer + 23;
    my $shift = $window_size - $max_pair_span;

    my @all_pairs;
    while ($start < $end ){
        $self->log->debug("pair window start: $start");
        my $pair_rs = $pairs->search({ 'chr_start' => { -between => [ $start, $start + $window_size ]} });
        my @crisprs = $pair_rs->all;
        push @all_pairs, @{ $self->find_pairs(\@crisprs,\@crisprs, $options) || [] };
        $start+=$shift;
    }

    my %unique = map { $_->{left_crispr}{id} . ":" . $_->{right_crispr}{id} => $_ } @all_pairs;
    return [ values %unique ];
}

#a and b are two arrayrefs of crisprs you want to check for pairs.
#they can (and often will be) be a reference to the same list.
sub find_pairs {
    my ( $self, $list_a, $list_b, $options ) = @_;

    #make sure we get a species and schema if we are getting db data
    if ( $options->{get_db_data} ) {
        die "You must provide a species id if you want db data" 
            unless defined $options->{species_id};

        die "You must provide a schema if you want db data" 
            unless defined $self->schema;
    }

    $self->log->debug( "Finding pairs: ", scalar(@{$list_a}), ", ", scalar(@{$list_b}) );

    my %pairs; #use a hash to avoid duplicates
    for my $first ( @{ $list_a } ) {
        for my $second ( @{ $list_b } ) {
            my $valid_pair;

            #make sure the earlier pam site is treated as first
            #this is duplicated, but this is less confusing than swapping the vars i think
            if ( $first->pam_start < $second->pam_start ) {
                next if defined $pairs{ $first->id . ":" . $second->id };
                $valid_pair = $self->_check_valid_pair( $first, $second );
            }
            elsif ( $first->pam_start > $second->pam_start ) {
                #we have to swap the keys around here, because we always store them
                #in the unique hash as left:right.
                next if defined $pairs{ $second->id . ":" . $first->id };
                $valid_pair = $self->_check_valid_pair( $second, $first );
            }
            #if its the same it will be skipped.

            #wasn't a valid pairing, regardless of distance
            next unless defined $valid_pair;

            my $key = $valid_pair->{left_crispr}{id} . "_" . $valid_pair->{right_crispr}{id};
            $pairs{ $key } = $valid_pair;

            #if we have sorted lists we can maybe uncomment this for faster processing
            # last if $distance > $self->max_spacer;
        }
    }

    #if the user wants database data then now is the time to retrieve it
    if ( $options->{get_db_data} ) {
        $self->log->warn("Retrieving DB pair data");
        my $db_data = $self->schema->resultset('CrisprPair')->fast_search_by_ids( {
            ids        => [ keys %pairs ], 
            species_id => $options->{species_id}
        } );

        $self->log->debug("Found " . scalar( keys %{ $db_data } ) . " pairs");

        #now insert anything we found into the original pairs hash
        while ( my ( $pair_id, $data ) = each %{ $db_data } ) {
            $pairs{$pair_id}->{db_data} = $data;
        }
    }

    #allow the user to specify if they want the pairs sorted.
    #default is no for better performance
    if ( $options->{sort_pairs} ) {
        $self->log->debug( "Sorting pairs" );
        
        #return by sorted keys (as a lower key corresponds to a lower chr position)
        return [ 
            map { $pairs{$_} } 
                sort { 
                    my ( $a1, $a2 ) = split "_", $a; #ids are like: 1_2 
                    my ( $b1, $b2 ) = split "_", $b; 
                    return $a1 <=> $b1 || $a2 <=> $b2
                } keys %pairs 
        ];
    }
    else {
        return [ values %pairs ];
    }
}

sub _check_valid_pair {
    my ( $self, $first, $second ) = @_;

    my $orientation;
    if ( $first->pam_left && $second->pam_right ) {
        #tail to tail
        $orientation = 0;
    }
    elsif ( $first->pam_right && $second->pam_left ) {
        #head to head
        return unless $self->include_h2h; #see if we want these
        $orientation = 1;
    }
    else {
        return; #not a valid pair
    }


    #22 to be from the end, 1k for distance
    # subtract 1 to get he number of bases between end
    # of first crispr and start of second crispr
    my $distance = $second->chr_start - ($first->chr_start+22) - 1;
    return if $distance > $self->max_spacer || $distance < $self->min_spacer;

    return {
        spacer       => $distance,
        orientation  => $orientation,
        left_crispr  => $first->as_hash,
        right_crispr => $second->as_hash,
        id           => $first->id . "_" . $second->id,
        db_data      => undef,#optionally populated later
    }
}

1;

__END__