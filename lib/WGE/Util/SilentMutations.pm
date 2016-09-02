package WGE::Util::SilentMutations;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::SilentMutations::VERSION = '0.099';
}
## use critic


use strict;
use warnings;

use Sub::Exporter -setup => {
    exports => [ qw(
        get_silent_mutations
    ) ]
};

use Bio::Seq;
use Bio::Tools::CodonTable;

#maybe we should build a hash table instead of calculating this every time

sub get_silent_mutations {
    my ( $seq ) = @_;

    die "Provided sequence must be 3 bases long" unless length( $seq ) == 3;

    #get the amino acid corresponding to the users sequence
    my $aa = Bio::Seq->new( -seq => $seq )->translate->seq;
    my $t = Bio::Tools::CodonTable->new;
    my @codons = Bio::Tools::CodonTable->new->revtranslate( $aa );

    #do we need to only show silent mutations that are a point mutation?
    #if so this code will do it:

    #return all valid codons that are only 1 base different from the users sequence
    #the xor tells us the difference between two strings, and the tr counts
    #the number of mismatches.

    #return grep { ($seq ^ $_) =~ tr/\001-\255// == 1 } @codons;

    return @codons;
}

sub _build_codon_table {
    my $amino_acids = "FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG";

    #iterating all nucleotides in the order t c a g will yield the above string.
    #taken directory from the Bio::Tools::CodonTable source code

    my %acids;

    #generate all possible codons
    my @nucs = qw( t c a g );
    my $x = 0;
    for my $i ( @nucs ) {
        for my $j ( @nucs ) {
            for my $k ( @nucs ) {
                my $codon = "$i$j$k";
                #take the next amino acid from the above string, and add this codon
                #to its list of codons
                push @{ $acids{ substr($amino_acids, $x++, 1) } }, $codon;
            }
        }
    }

    #TODO: check the amino acids are right

    #how much memory will this use??

    my %silent_mutations;
    while ( my ( $key, $codons ) = each %acids ) {
        for my $i ( 0 .. @{ $codons }-1 ) {
            my $current = $codons->[$i];

            #make the array value for this codon all the other codons that produce
            #the same amino acid. the grep removes THIS amino acid from the resulting
            #list.

            $silent_mutations{ $current } = [ grep { $_ ne $current } @{$codons} ];
        }
        delete $acids{$key}; #try and save some memory
    }

    return \%silent_mutations;
}