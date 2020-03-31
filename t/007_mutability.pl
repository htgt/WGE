#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 6;
use Test::MockObject;
use FindBin qw/$Bin/;
use WGE::Util::Mutability qw/calculate_mutability/;
use lib "$Bin/lib";

sub mock {
    my %args = @_;
    my $obj = Test::MockObject->new;
    foreach my $key ( keys %args ) {
        my $arg = $args{$key};
        if ( ref $arg eq ref {} ) {
            $arg = mock(%{$arg});
        }
        $obj->mock($key, sub { $arg });
    }
    return $obj;
}

sub increment {
    my ( $obj, $amount ) = @_;
    $amount //= 1;
    $obj->{chr_start} += $amount;
    $obj->{chr_end}   += $amount;
    return $obj;
}

{ # gene +, exon +
    my $exon = mock(
        gene      => { strand => 1 },
        strand    => 1,
        phase     => 0,
        end_phase => 0,
        chr_start => 101,
        chr_end   => 160,
    );
    is(calculate_mutability($exon, mock(strand => 1, chr_start =>  99, chr_end => 121)), 1);
    is(calculate_mutability($exon, mock(strand => 1, chr_start => 100, chr_end => 122)), 2);
    is(calculate_mutability($exon, mock(strand => 1, chr_start => 101, chr_end => 123)), 0);
    is(calculate_mutability($exon, mock(strand => 1, chr_start => 102, chr_end => 124)), 1);
    is(calculate_mutability($exon, mock(strand => 1, chr_start => 103, chr_end => 125)), 2);
}

{
    my $exon = mock(
        gene    => { strand => 1 },
        strand  => 1,
        phase   => 1,
        end_phase => 1,
        chr_start => 32319077,
        chr_end   => 32319325,
    );
    is(calculate_mutability($exon, mock(chr_start => 32319080, chr_end => 32319102, strand => 1)), 1);
}

