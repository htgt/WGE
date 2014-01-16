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
#they can be a reference to the same list.
sub find_pairs {
    my ( $self, $a, $b ) = @_;

    $self->log->debug( "Finding pairs: ", scalar(@{$a}), ", ", scalar(@{$b}) );

    my @pairs;
    for my $first ( @{ $a } ) {
        for my $second ( @{ $b } ) {
            my $valid_pair;

            #make sure the earlier pam site is treated as first
            if ( $first->pam_start < $second->pam_start ) {
                $valid_pair = $self->_check_valid_pair( $first, $second );
            }
            elsif ( $first->pam_start > $second->pam_start ) {
                $valid_pair = $self->_check_valid_pair( $second, $first );
            }
            #if its the same we skip it.

            #wasn't a valid pairing, regardless of distance
            next unless defined $valid_pair;

            #if we have sorted lists we can uncomment this
            # last if $distance > 1000;

            push @pairs, $valid_pair;
        }
    }

    return \@pairs;
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
    my $distance = $second->chr_start - ($first->chr_start+22);
    return if $distance > $self->max_spacer || $distance < $self->min_spacer;

    return {
        spacer       => $distance,
        orientation  => $orientation,
        left_crispr  => $first->as_hash,
        right_crispr => $second->as_hash,
    }
}

1;

__END__