#!/usr/bin/env perl
use strict;
use warnings;

use WGE::Model::DB;
use YAML::Any qw( Load );
use Data::Dumper;
use feature 'say';

# Generate files containing the number of off-targets found in each category for each crispr
# These files can be used to generate off-target count distributions in R
# Script ran in about 2.5 hours for all human crisprs

my $species = $ARGV[0];
$species ||= 'Human';

my $species_lc = lc($species);
my $model = WGE::Model::DB->new();

my $files;
foreach my $mm_category (0..4){
	open (my $fh,  ">", $species_lc."_".$mm_category."mm.csv");
	$files->{$mm_category} = $fh;
}

my @chromosomes = map {$_->name} $model->schema->resultset('Chromosome')->search({ species_id => $species});
say "Finding off target summaries for chromosomes: ",@chromosomes;

foreach my $chr (@chromosomes){
say STDERR "running query for chromosome $chr...";
my $sql_query = "select off_target_summary from crisprs_$species_lc where chr_name='$chr' and off_target_summary is not null";
my $sql_result =  $model->schema->storage->dbh_do(
    sub {
         my ( $storage, $dbh ) = @_;
         my $sth = $dbh->prepare( $sql_query );
         $sth->execute();
         $sth->fetchall_arrayref();
        }
);
say STDERR "chromosome $chr query done";

say STDERR "writing off target counts for chromosome $chr..";
foreach my $result (@$sql_result){
	my $off_target_counts = Load($result->[0]);
	foreach my $mm_category (0..4){
		my $number_of_ots = $off_target_counts->{$mm_category};
		my $fh = $files->{$mm_category};
		print $fh $number_of_ots."\n";
	}
}
say STDERR "chromosome $chr off target counts written";
}
