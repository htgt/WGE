#!/usr/bin/env perl

use strict;
use warnings;

use feature qw( say );
use Data::Dumper;

use WGE::Util::OffTargetServer;
use Bio::SeqIO;
use TryCatch;
use Bio::Perl qw( revcom_as_string );

$|=1;

my $species = "mouse";
say "Species: $species";

open (my $fh, "<", $ARGV[0]) or die "Could not open file $ARGV[0] for reading - $!";
my $is_pam_left = $ARGV[1];

open (my $out_fh, ">", "crispr_off_targets.tsv") or die "Could not open output file - $!";
print $out_fh join "\t", qw(sequence_name crispr_sequence off_target_summary error);
print $out_fh "\n";

my $ots_server = WGE::Util::OffTargetServer->new;

my $fasta = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );

my $pam_right;
if($is_pam_left){
    $pam_right = "false";
    say "Finding off-targets for supplied sequence with PAM left";
}
else{
    $pam_right = "true";
    say "Finding off-targets for supplied sequence with PAM right";
}

my $count = 0;
while (my $sequence = $fasta->next_seq){
	$count++;
    say "$count: ".$sequence->id;

	my $seq = $sequence->seq;

    if(length $seq == 19){
        # All sequences are 5' to 3'
	    # Extend with G left (5')
        $seq = "G".$seq;
    }

    my $search_params = {
        sequence  => $seq,
        pam_right => $pam_right,
        species   => $species,
    };

    my $off_target_data = {};
    try {
        $off_target_data = $ots_server->find_off_targets_by_seq($search_params);
    }
    catch ( $e ) {
        $off_target_data->{error} = $e;
    }

    my $output = join "\t", (
        $sequence->id,
        $seq,
        $off_target_data->{off_target_summary} // "",
        $off_target_data->{error} // "",
    );

    print $out_fh $output."\n";
}
close $out_fh;