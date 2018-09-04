#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use Getopt::Long;
use List::Util qw/first/;
use Pod::Usage qw/pod2usage/;
use Text::CSV;

#types of genomic data to capture
my %types = map { $_ => 1 } qw/gene exon CDS rna/;

#GFF data to directly output
my @fields = qw/transcript_id protein_id biotype description/;

#columns to write to output
my @columns = (
    qw/id feature_type_id chr_name chr_start chr_end strand rank name parent_id gene_type gene_id/,
    @fields
);

#grab these types of genomic data by grouping them in with some other... lots of RNA
my %synonyms = map { $_ => 'rna' } qw/transcript primary_transcript mRNA miRNA/;
$synonyms{pseudogene} = 'gene';

#rename some fields before including them
my %field_maps = (
    Parent       => 'parent_id',
    Name         => 'name',
    gene_biotype => 'biotype',
);

sub extract_id {
    my $dbx = shift;
    my $field = first { $dbx->{$_} } qw/HGNC Genbank GeneID/;
    return if not $field;
    return ( $field, $dbx->{$field} );
}
my %genes   = ();
my %strands = (
    '+' => 1,
    '-' => -1
);

sub read_line {
    my $line = shift;
    chomp $line;
    return if /^[#]/xms;
    return if not /^NC_0000/xms;
    my (
        $seqname, $source, $feature, $start, $end,
        $score,   $strand, $frame,   $atts
    ) = split m/\t/x, $line;

    #apply synonyms
    my $original_feature = $feature;
    if ( exists $synonyms{$feature} ) {
        $feature = $synonyms{$feature};
    }

    my %fields = split /[;=]/x, $atts;
    my $gene = exists $fields{gene} ? $fields{gene} : '?';
    
    #filter out nonselected types
    return if not exists $types{$feature};
    
    my $id = $fields{ID};
    $genes{$id}->{rank}++;
    my $rank = $genes{$id}->{rank};
    if ( $rank > 1 ) {
        $id = join '_', $id, $rank;
    }
    my ($chr) = $seqname =~ m/^NC_[0]+([1-2]?[0-9])\.[0-9]+/x;
    my %dbx = map { split /:/x, $_, 2 } split /,/x, $fields{Dbxref};
    my ( $dbkey, $dbval ) = extract_id( \%dbx );
    $strand = exists $strands{$strand} ? $strands{$strand} : 0;
    my %data = (
        id              => $id,
        feature_type_id => $feature,
        chr_name        => $chr,
        chr_start       => $start,
        chr_end         => $end,
        strand          => $strand,
        gene_type       => $dbkey,
        gene_id         => $dbval,
        rank            => $rank,
    );

    #read in fields
    foreach my $field (@fields) {
        $data{$field} = $fields{$field} // q//;
    }
    #read in renamed fields
    foreach my $field ( keys %field_maps ) {
        $data{ $field_maps{$field} } = $fields{$field} // q//;
    }
    if ( ( not $data{biotype} ) and ( $feature ne $original_feature ) ) {
        $data{biotype} = $original_feature;
    }
    
    #find and annotate with the parent
    my $parent = $data{parent_id};
    if ( $parent and not exists $genes{$parent} ) {
        return;
    }
    if ($parent) {
        if ( not $parent =~ m/^(gene|rna)/x ) {
            $parent = $genes{$parent}->{parent};
        }
        $genes{$id}->{parent} = $parent;
        $data{parent_id} = $parent;
    }

    return \%data;
}

sub print_header {
    my ( $csv, $output, $columns ) = @_;
    $csv->print( $output, $columns );
    $csv->column_names(   $columns );
    return;
}

my ( $file, $limit, $help );
GetOptions(
    'limit=i' => \$limit,
    'file=s'  => \$file,
    'help|?'  => \$help,
) or pod2usage(2);
pod2usage( -verbose => 2 ) if $help;
croak "Missing required argument --file" if not defined $file;

my $csv = Text::CSV->new( { binary => 1, eol => "\n" } )
  or croak 'Cannot export CSV';
my $num = 0;
open my $input,  '<', $file or croak "Could not open $file for reading: $!";
open my $output, '>', "$file.csv" or croak "Could not open $file.csv for writing: $!";
print_header( $csv, $output, \@columns );
while (<$input>) {
    if ( my $data = read_line( $_ ) ) {
        $csv->print_hr( $output, $data );
        $num++;
    }
    last if $limit && $num >= $limit;
}
close $output or croak "Could not close $file.csv: $!";
close $input or croak "Could not close $file: $!";

__END__

=head1 NAME

gff_to_geneset.pl - Converts a GFF file into a GeneSet which can be used
as a source for a track.

=head1 SYNOPSIS

gff_to_geneset.pl --file GRCh38_latest_genomic.gff [OPTIONS...]

=head1 ARGUMENTS

=over 4

=item B<-f --file> F<PATH>

A GFF file containing genomic data to import

=item B<-l --limit> I<NUMBER>

Stop after importing I<number> items (mostly for quick debugging).

=back

