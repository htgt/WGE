#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use Getopt::Long;
use Pod::Usage;
use Text::CSV;
our $VERSION = 0.01;

my ( $help, $line, $source );
GetOptions(
    'line=s'   => \$line,
    'source=s' => \$source,
    'help|?'   => \$help,
) or croak 'Cannot parse arguments';
pod2usage( -exitval => 0, -verbose => 3 ) if $help;
croak "--line is required\n"   if not $line;
croak "--source is required\n" if not -e $source;

my $variants = Haplotype->new( "$line.csv",
    qw/chrom pos ref alt qual filter genome_phasing/ );

open my $input, '<', $source or croak $!;
while (<$input>) {
    next if m/^\#/xms;
    my (
        $chrom, $pos,    $vcf_id, $ref,    $alt,
        $qual,  $filter, $info,   $format, $data
    ) = split /\t/xms;
    my ($phasing) = $data =~ m/^(\d(?:[|\/]\d)?)/xms;
    $qual = $qual eq q/./ ? q// : $qual;
    $info = q/./;
    $variants->add( $chrom, $pos, $ref, $alt, $qual, $filter, $phasing );
}
close $input or croak $!;

package Haplotype;

sub add {
    my ( $self, @data ) = @_;
    $self->{csv}->print( $self->{file}, \@data );
    return 1;
}

sub DESTROY {
    my $self = shift;
    if ( exists $self->{destroyed} ) {
        return 0;
    }
    close $self->{file} or croak $!;
    $self->{destroyed} = 1;
    return 1;
}

sub dispose {
    my $self = shift;
    return $self->DESTROY;
}

sub new {
    my ( $class, $filename, @columns ) = @_;
    my $exists = -e $filename;
    open my $file, '>>', $filename or croak $!;
    my $csv = Text::CSV->new( { binary => 1, eol => "\n" } );
    if ( not $exists ) {
        $csv->print( $file, \@columns );
    }
    return bless {
        file => $file,
        csv  => $csv,
    }, $class;
}

__END__

=head1 NAME

import_vcf.pl - Reads a VCF and exports the data needed for a haplotype track.

=head1 USAGE

import_vcf.pl --line <line name> --source <input VCF> [--species <species>]

=head1 OPTIONS

=over 8

=item B<--line>

The name of the cell line. Will result in a file named I<<line>.csv>

=item B<--source>

The VCF file to read.

=back

=head1 DESCRIPTION

This program reads a VCF and exports the specific data needed to create a haplotype track (as a CSV which can be \copy-ed in).

