use Test::More import => [ '!pass' ], tests => 22;

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/lib"; #add the test lib

use Test::WGE;
use JSON;

use Data::Dumper;

my $test = Test::WGE->new;
$test->load_fixtures;

my $mech = $test->mech;

# Crispr report
$mech->get_ok('/crispr/245377736');
$mech->content_contains('Human');
$mech->content_contains('17:46154207-46154229');
$mech->content_contains('CCTGTGTCAGTGAAACTTACTCT');
$mech->content_contains('{0: 1, 1: 0, 2: 0, 3: 9, 4: 126}');
$mech->content_contains('Found 2 Related Crispr Pairs');
$mech->content_contains('245377736_245377738');

# Pair report
$mech->get_ok('/crispr_pair/245377736_245377738');
$mech->content_contains('Spacer: 1');
$mech->content_contains('17:46154207-46154229');
$mech->content_contains('17:46154231-46154253');
$mech->content_contains('CCTGTGTCAGTGAAACTTACTCT');
$mech->content_contains('AGAATCCCTTCCACTTTAGGAGG');
$mech->content_contains('Complete');

my $auth_mech = $test->authenticated_mech;
$auth_mech->get_ok('/crispr_bookmark_status/245377736', 'can fetch crispr bookmark status');
is_deeply(from_json($auth_mech->content), { is_bookmarked => 0 }, 'crispr 245377736 not bookmarked');
$auth_mech->get_ok('/bookmark_crispr/245377736/add', 'can add crispr bookmark');
$auth_mech->get_ok('/crispr_bookmark_status/245377736', 'can fetch crispr bookmark status');
is_deeply(from_json($auth_mech->content), { is_bookmarked => 1 }, 'crispr 245377736 has been bookmarked');
$auth_mech->get_ok('/bookmark_crispr/245377736/remove', 'can remove crispr bookmark');
$auth_mech->get_ok('/crispr_bookmark_status/245377736', 'can fetch crispr bookmark status');
is_deeply(from_json($auth_mech->content), { is_bookmarked => 0 }, 'crispr 245377736 no longer bookmarked');