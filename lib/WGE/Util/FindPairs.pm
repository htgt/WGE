package WGE::Util::FindPairs;

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
    required => 1,
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

#a and b are two arrayrefs of crisprs you want to check for pairs.
#they can (and often will be) be a reference to the same list.
sub find_pairs {
    my ( $self, $a, $b, $options ) = @_;

    #make sure we get a species and schema if we are getting db data
    if ( $options->{get_db_data} ) {
        die "You must provide a species id if you want db data" 
            unless defined $options->{species_id};

        die "You must provide a schema if you want db data" 
            unless defined $self->schema;
    }

    $self->log->debug( "Finding pairs: ", scalar(@{$a}), ", ", scalar(@{$b}) );

    my %pairs; #use a hash to avoid duplicates
    for my $first ( @{ $a } ) {
        for my $second ( @{ $b } ) {
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

    return [ values %pairs ];
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
        db_data      => undef,#optionally populated later
    }
}

1;

__END__