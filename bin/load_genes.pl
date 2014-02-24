#!/usr/bin/env perl

use strict;
use warnings;

use feature qw( say );
use YAML::Any qw( LoadFile );
use WGE::Model::DB;

die "Usage: load_genes.pl <filenames>" unless @ARGV == 1;

my $DB = WGE::Model::DB->new();

use Try::Tiny;

#load each yaml file into the db
for my $filename ( @ARGV ) {
    my $genes_yaml = LoadFile( $filename ) || die "Couldn't open $filename: $!";

    $DB->schema->resultset('Gene')->load_from_hash( $genes_yaml );
}

1;
