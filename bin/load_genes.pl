#!/usr/bin/env perl

use strict;
use warnings;

use feature qw( say );
use YAML::Any qw( LoadFile );
use WGE::Model::DB;

die "Usage: load_genes.pl <filenames>" unless @ARGV == 1;

my $db = WGE::Model::DB->new();

use Try::Tiny;

$db->schema->txn_do(sub {
    #load each yaml file into the db
    for my $filename ( @ARGV ) {
        my $genes_yaml = LoadFile( $filename ) || die "Couldn't open $filename: $!";
        my @species = keys %{ $genes_yaml };
        $db->schema->resultset('Gene')->search({ species_id => { -in => \@species } })->delete;

        $db->schema->resultset('Gene')->load_from_hash( $genes_yaml );
    }
});

1;
