#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 48;
use Test::MockObject;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use WGE::Util::Mutability qw/calculate_phasing/;

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

sub crispr {
    my %args = @_;
    $args{chr_end} = $args{chr_start} + 22;
    return \%args;
}

{
    my $exon = mock(
        strand    => 1,
        phase     => 0,
        end_phase => 0,
        chr_start => 101,
        chr_end   => 160,
    );
    is(calculate_phasing($exon, crispr(pam_right => 1, chr_start =>  99)), 2);
    is(calculate_phasing($exon, crispr(pam_right => 1, chr_start => 100)), 0);
    is(calculate_phasing($exon, crispr(pam_right => 1, chr_start => 101)), 1);
    is(calculate_phasing($exon, crispr(pam_right => 1, chr_start => 102)), 2);
    is(calculate_phasing($exon, crispr(pam_right => 1, chr_start => 103)), 0);
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
    is(calculate_phasing($exon, crispr(chr_start => 32319080, pam_right => 1)), 0);
    is(calculate_phasing($exon, crispr(chr_start => 32319081, pam_right => 1)), 1);
    is(calculate_phasing($exon, crispr(chr_start => 32319082, pam_right => 1)), 2);
}

{ # + 1:2
    my $exon = mock(
        strand    => 1,
        phase     => 1,
        end_phase => 2,
        chr_start => 44907760,
        chr_end   => 44907952,
    );
    is(calculate_phasing($exon, crispr(chr_start => 44907738, pam_right => 1)), -1);
    is(calculate_phasing($exon, crispr(chr_start => 44907739, pam_right => 0)), -1);
    is(calculate_phasing($exon, crispr(chr_start => 44907746, pam_right => 1)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907752, pam_right => 0)), -1);
    is(calculate_phasing($exon, crispr(chr_start => 44907752, pam_right => 1)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907755, pam_right => 1)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907764, pam_right => 0)),  2);
    is(calculate_phasing($exon, crispr(chr_start => 44907764, pam_right => 1)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907767, pam_right => 1)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907769, pam_right => 0)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907779, pam_right => 1)),  1);

    is(calculate_phasing($exon, crispr(chr_start => 44907914, pam_right => 1)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907923, pam_right => 1)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907931, pam_right => 0)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907931, pam_right => 1)),  0);
    is(calculate_phasing($exon, crispr(chr_start => 44907932, pam_right => 0)),  2);
    is(calculate_phasing($exon, crispr(chr_start => 44907940, pam_right => 0)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 44907941, pam_right => 0)),  2);
    is(calculate_phasing($exon, crispr(chr_start => 44907949, pam_right => 1)), -1);
}

{ # - 0:1
    my $exon = mock(
        strand    => -1,
        phase     => 0,
        end_phase => 1,
        chr_start => 45315465,
        chr_end   => 45315597,
    );
    is(calculate_phasing($exon, crispr(chr_start => 45315557, pam_right => 1)),  0); 
    is(calculate_phasing($exon, crispr(chr_start => 45315558, pam_right => 1)),  2); 
    is(calculate_phasing($exon, crispr(chr_start => 45315564, pam_right => 1)),  2); 
    is(calculate_phasing($exon, crispr(chr_start => 45315579, pam_right => 1)),  2); 
    is(calculate_phasing($exon, crispr(chr_start => 45315582, pam_right => 0)),  1); 
    is(calculate_phasing($exon, crispr(chr_start => 45315586, pam_right => 1)), -1); 
    is(calculate_phasing($exon, crispr(chr_start => 45315587, pam_right => 1)), -1); 
    is(calculate_phasing($exon, crispr(chr_start => 45315590, pam_right => 1)), -1); 
    is(calculate_phasing($exon, crispr(chr_start => 45315591, pam_right => 1)), -1); 
    is(calculate_phasing($exon, crispr(chr_start => 45315593, pam_right => 0)), -1); 
    is(calculate_phasing($exon, crispr(chr_start => 45315596, pam_right => 0)), -1); 
    is(calculate_phasing($exon, crispr(chr_start => 45315597, pam_right => 0)), -1); 
    is(calculate_phasing($exon, crispr(chr_start => 45315599, pam_right => 1)), -1); 
}

{ # - 1:0
    my $exon = mock(
        strand    => -1,
        phase     => 1,
        end_phase => 0,
        chr_start => 45317825,
        chr_end   => 45317979,
    );
    is(calculate_phasing($exon, crispr(chr_start => 45317808, pam_right => 0)), -1);
    is(calculate_phasing($exon, crispr(chr_start => 45317809, pam_right => 1)),  2);
    is(calculate_phasing($exon, crispr(chr_start => 45317818, pam_right => 1)),  2);
    is(calculate_phasing($exon, crispr(chr_start => 45317820, pam_right => 0)),  0);
    is(calculate_phasing($exon, crispr(chr_start => 45317824, pam_right => 0)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 45317824, pam_right => 1)),  2);
    is(calculate_phasing($exon, crispr(chr_start => 45317846, pam_right => 1)),  1);
    is(calculate_phasing($exon, crispr(chr_start => 45317847, pam_right => 1)),  0);
}
