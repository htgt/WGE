#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use LIMS2::REST::Client;
use YAML::Any qw( LoadFile DumpFile );
use Try::Tiny;
use Log::Log4perl qw( :easy );
use Data::Dumper;
use Path::Class;
use Bio::Perl qw( revcom );

Log::Log4perl->easy_init($DEBUG);

my ( $species, @ids, $fq_file, $crispr_file, $pair_file );
GetOptions(
    "help"               => sub { pod2usage( 1 ) },
    "man"                => sub { pod2usage( 2 ) },
    "species=s"          => sub { my ( $name, $val ) = @_; $species = ucfirst( lc $val ); },
    "ids=s{,}"           => \@ids,
    "fq-file=s"          => sub { my ( $name, $val ) = @_; $fq_file = file( $val ); },
    "crispr-yaml-file=s" => \$crispr_file,
) or pod2usage( 2 );

die pod2usage( 2 ) unless $species and @ids and ($fq_file or $crispr_file);


#check which kind of ids we got
my @exon_ids = grep { /^ENS(MUS)?E\d+$/ } @ids;
my @crispr_ids = grep { /^\d+$/ } @ids;
die "You must provide exons OR crisprs ids, not both." if @exon_ids and @crispr_ids;

my $client = LIMS2::REST::Client->new_with_config(
    configfile => $ENV{WGE_REST_CLIENT_CONFIG}
);

#ugly duplication. refactor
my $all_crisprs;
if ( @exon_ids ) {
    WARN "Some exon ids were invalid" unless @exon_ids == @ids;
    DEBUG "Fetching crisprs for exon ids: " . join( ", ", @exon_ids );
    $all_crisprs = $client->GET(
        'crisprs_by_exon', 
        { exons => \@exon_ids, species => $species }
    );
}
elsif ( @crispr_ids ) {
    WARN "Some crispr ids were invalid" unless @crispr_ids == @ids;
    DEBUG "Fetching crisprs for exon ids: " . join( ", ", @crispr_ids );
    $all_crisprs = $client->GET(
        'crispr', 
        { id => \@crispr_ids, species => $species, return_array => 1 }
    );
}
else {
    die "Couldn't find any crispr ids or exon ids in: " . join ", ", @ids;
}

die "Couldn't find any crisprs!" unless @{ $all_crisprs };

my $fq_fh = $fq_file->openw or die "Can't open $fq_file: $!";
my %crispr_data;
for my $crispr ( @{ $all_crisprs } ) {
    $crispr->{ensembl_exon_id} ||= 'ENSE000'; #if there's no exon id use this placeholder
    #create the empty hash to conform to how we used to do crisprs
    $crispr_data{ $crispr->{ensembl_exon_id} }->{ $crispr->{id} } = {};

    #write the fq lines
    my $orientation = ( $crispr->{pam_right} ) ? "B" : "A";

    say $fq_fh ">" . $crispr->{ensembl_exon_id} . "_" . $crispr->{id} . $orientation;
    #we always store crisprs as pam right in the fq file.
    say $fq_fh ( $crispr->{pam_right} ) ? $crispr->{seq} : revcom( $crispr->{seq} )->seq;
}

INFO "Total number of crisprs found: " . scalar( @{ $all_crisprs } );
INFO join "\n", map { $_ . ": " . scalar( keys %{ $crispr_data{$_} } ) } keys %crispr_data;

DumpFile( $crispr_file, \%crispr_data );

1;

__END__