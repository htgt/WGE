use Test::More import => [ '!pass' ], tests => 20;

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/lib"; #add the test lib

use Test::WGE;

use Data::Dumper;

my $test = Test::WGE->new;
$test->load_fixtures;

my $mech = $test->mech;

# Genoverse browse controller
{
    my $chr = 17;
    my $start = 46154227;
    my $end = 46154403;
    my $assembly = 'GRCh37';
    my $crispr_id = '245377747';
    my $pair_id = '245377760_245377764';
    my $exon_id = 'ENSE00002771605';

    my $coords = {
    	chromosome   => $chr,
    	genome       => $assembly,
    	browse_start => $start,
    	browse_end   => $end,
    };

    $mech->get_ok($test->get_uri('/genoverse_browse', $coords), 'can browse by coordinates' );
    is($mech->forms->[0]->value('genome'), $assembly, 'genome correct');
    is($mech->forms->[0]->value('chromosome'), $chr, 'chromosome correct');
    is($mech->forms->[0]->value('browse_start'), $start, 'start correct');
    is($mech->forms->[0]->value('browse_end'), $end, 'end correct');

    $mech->get_ok($test->get_uri('/genoverse_browse', { exon_id => $exon_id }), 'can browse by exon' );
    is($mech->forms->[0]->value('genome'), $assembly, 'genome correct');
    is($mech->forms->[0]->value('chromosome'), $chr, 'chromosome correct');
    is($mech->forms->[0]->value('browse_start'), $start, 'start correct');
    is($mech->forms->[0]->value('browse_end'), $end, 'end correct');

    $mech->get_ok($test->get_uri('/genoverse_browse', { crispr_id => $crispr_id }), 'can browse by crispr' );
    is($mech->forms->[0]->value('genome'), $assembly, 'genome correct');
    is($mech->forms->[0]->value('chromosome'), $chr, 'chromosome correct');
    is($mech->forms->[0]->value('browse_start'), 46153797, 'start correct');
    is($mech->forms->[0]->value('browse_end'), 46154797, 'end correct');

    $mech->get_ok($test->get_uri('/genoverse_browse', { crispr_pair_id => $pair_id }), 'can browse by crispr pair' );
    is($mech->forms->[0]->value('genome'), $assembly, 'genome correct');
    is($mech->forms->[0]->value('chromosome'), $chr, 'chromosome correct');
    is($mech->forms->[0]->value('browse_start'), 46153872, 'start correct');
    is($mech->forms->[0]->value('browse_end'), 46154872, 'end correct');

}