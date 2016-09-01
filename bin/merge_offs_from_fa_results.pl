#!/usr/bin/env perl

use strict;
use warnings;

use feature qw( say );
use Data::Dumper;

my ($fa, @result_files) = @ARGV;

my @seq_ids;
my $sequences_by_id = {};

say "Fetching seq IDs from fasta file";
open (my $fa_fh, "<", $fa) or die "Could not open file $fa for reading";
my $curr_id;
foreach my $line (<$fa_fh>){
    chomp $line;
	if($line=~/^>/){
    	$line =~ s/^>//;
    	$curr_id = $line;
    	push @seq_ids, $line;
    }
    else{
    	$sequences_by_id->{$curr_id} = $line;
    }
}
close $fa_fh;

my $results = {};
my $results_fail = {};
foreach my $file (@result_files){
	open (my $fh, "<", $file) or die "Could not open file $file for reading";

	say "Storing results from $file";
	foreach my $result_line (<$fh>){
        my ($id, $seq, $ot, $error) = split "\t", $result_line;
        if($error=~/\w+/){
        	$results_fail->{$id} = $result_line;
        }
        else{
        	$results->{$id} = $result_line;
        }
    }
    close $fh;
}

open (my $out_fh, ">", "output.tsv") or die "Could not open output file for writing";
open (my $fails_fh, ">", "fails_to_repeat.fa") or die "Could not open fails_to_repeat.fa for writing";
say "Generating output.tsv file";
foreach my $id (@seq_ids){
	if(exists $results->{$id}){
		print $out_fh $results->{$id};
	}
	elsif(exists $results_fail->{$id}){
		print $out_fh $results_fail->{$id};
		say "Warning: error for $id - ".$results_fail->{$id};
		my $seq = $sequences_by_id->{$id};
		print $fails_fh ">$id\n";
		print $fails_fh "$seq\n";
	}
	else{
		say "Warning: no result for $id";
		print $out_fh join "\t", $id, "","","no result";
		print $out_fh "\n";
		my $seq = $sequences_by_id->{$id};
		print $fails_fh ">$id\n";
		print $fails_fh "$seq\n";
	}
}
