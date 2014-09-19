#!/usr/bin/env perl
use strict;
use warnings;

use WGE::Model::DB;
use Getopt::Long;
use feature qw( say );
use Try::Tiny;

my ( $species, $assembly, $file, $commit );
GetOptions(
    'species=s'   => \$species,
    'assembly=s'  => \$assembly,
    'data-file=s' => \$file,
    'commit'      => \$commit,
);

$assembly //= 'GRCh38';
$species  //= 'Human';

my $model = WGE::Model::DB->new;

my %chr_ids;
my @chromosomes = $model->schema->resultset("Chromosome")->search( { species_id => $species } );
for my $chr ( @chromosomes ) {
    $chr_ids{ 'chr' . $chr->name } = $chr->id;
}

$model->txn_do(
    sub {
        try{
            open (my $fh, "<", $file) or die $!;
            update_loci( $fh );
            unless ( $commit ) {
                print "non-commit mode, rollback\n";
                $model->txn_rollback;
            }
        }
        catch {
            print "failed: $_\n";
            $model->txn_rollback;
        };
    }
);

sub update_loci {
    my ( $fh ) = shift;

    my $count = 0;
    foreach my $line ( <$fh> ){
        $count++;
        chomp $line;
        my ($chr,$start,$end, $identifier) = split "\t", $line;
        my ($oligo_id, $strand) = split ":", $identifier;

        my $params = {
            design_oligo_id => $oligo_id,
            assembly_id     => $assembly,
            chr_start       => $start,
            chr_end         => $end,
            chr_strand      => $strand,
            chr_id          => $chr_ids{ $chr },
        };

        say "Adding new design oligo $oligo_id ( $count )";
        my $locus = $model->schema->resultset( 'DesignOligoLoci' )->create($params);

        unless ( $locus->chr_start == $start and $locus->chr_end == $end ) {
            die "Start and end coords not as expected. Expected: $start, $end, got: "
                . $locus->chr_start . ", "
                . $locus->chr_end . "\n";
        }
    }
}

