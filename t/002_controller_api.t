use Test::More import => [ '!pass' ], tests => 38;

use strict;
use warnings;

use YAML qw( LoadFile );
use URI;
use Path::Class;
use FindBin qw( $Bin );
use lib "$Bin/lib"; #add the test lib
use JSON;

use Test::WGE;

use Data::Dumper;

#move these tests to another file not requiring model stuff
my $test = Test::WGE->new;

$test->load_fixtures();

#add headers to make the next requests valid ajax
$test->add_ajax_headers;

#
#need to test actual model stuff in separate file too probably
#

# get species
{
    my $tests = [
        { name => 'get species', data => {}, expect => { 1 => "Human", 2 => "Mouse"} },
    ];
    # FIXME: does not work - why??
    #test_json('/api/get_all_species', $tests);
}

#gene_search
{
    my $tests = [
        { name => 'gene name error', data => {}, expect => { error => "Error: Name is required"} },
        {
            name   => 'gene species error ',
            data   => { name => 'APP' },
            expect => {error => "Error: Species is required"}
        },
        { name => 'CBX1 gene', data => { name => 'CBX1', species => 'Human' }, expect => ["CBX1"] },
        {
            name   => 'CBX1 case insensitive gene',
            data   => { name => 'cbx1', species => 'Human' },
            expect => ["CBX1"]
        },
        { name => 'empty gene list', data => { name => 'FAKE', species => 'Human' }, expect => [] },
    ];

    test_json( '/api/gene_search', $tests );
}

#exon_search
{
    #why does this use marker_symbol not name.
    my $tests = [
        { name => 'exon name error', data => {}, expect => { error => "Error: Marker_symbol is required" } },
        {
            name   => 'exon species error',
            data   => { marker_symbol => 'CBX1' },
            expect => {error => "Error: Species is required"}
        },
        {
            name   => 'invalid gene error',
            data   => { species => 'Human', marker_symbol => 'FAKE' },
            expect => { error => "No exons found" }
        },
        {
            name   => 'CBX1 exons',
            data   => { species => 'Human', marker_symbol => 'CBX1' },
            expect => {
              transcript => 'ENST00000393408',
              exons => [
                { id => 452672, exon_id => "ENSE00001515177", rank => 1, len => 444, },
                { id => 452668, exon_id => "ENSE00002771605", rank => 2, len => 177, },
                { id => 452671, exon_id => "ENSE00002887933", rank => 3, len => 178, },
                { id => 452669, exon_id => "ENSE00000735651", rank => 4, len => 95, },
                { id => 452670, exon_id => "ENSE00001824299", rank => 5, len => 1528, },
              ]
            }
        },
    ];

    test_json( '/api/exon_search', $tests );
}

#pair_search
{
  # FIXME: test exon with no pairs error
    my $tests = [
        { name => 'empty exons error', data => {}, expect => { error => "Error: Exon_id[] is required" } },
        {
            name   => 'invalid exon error',
            data   => { 'exon_id[]' => 'ENSE0' },
            expect => { error => "Invalid exon id" }
        },
        {
            name => 'single exon pairs',
            data => { 'exon_id[]' => 'ENSE00000735651', species => 'Human' },
            expect => $test->json_data('single_exon_pairs_expected.json'),
        },
        {
            name => 'multiple exon pairs',
            data => { 'exon_id[]' => [ qw(ENSE00002771605 ENSE00002887933) ], species => 'Human' },
            expect => $test->json_data('multiple_exon_pairs_expected.json'),
        },
    ];

    test_json( '/api/pair_search', $tests );
}

#pair off-target search

#design attempt status

#designs in region

# crisprs/pairs in region
{
    my $chr = 17;
    my $start = 46153000;
    my $end = 46154000;
    my $assembly = "GRCh37";
    my $species = "Human";

    my $tests = [
        {
            name => 'all crisprs in region',
            data => { chr => $chr, start => $start, end => $end, assembly => $assembly, species_id => $species },
            expect => "crisprs_in_region.txt",
        },
        {
            name => 'exonic crisprs in region',
            data => { crispr_filter => 'exonic', chr => $chr, start => $start, end => $end, assembly => $assembly, species_id => $species },
            expect => "crisprs_in_region_exonic.txt",
        },
        {
            name => 'exon flanking crisprs in region',
            data => { crispr_filter => 'exon_flanking', flank_size => 50, chr => $chr, start => $start, end => $end, assembly => $assembly, species_id => $species },
            expect => "crisprs_in_region_flanking.txt",
        },
    ];
    test_gff('/api/crisprs_in_region', $tests);

    my $pairs_test = [
        {
            name => 'all crisprs pairs in region',
            data => { chr => $chr, start => $start, end => $end, assembly => $assembly, species_id => $species },
            expect => "crispr_pairs_in_region.txt",
        },
        {
            name => 'exonic crispr pairs in region',
            data => { crispr_filter => 'exonic', chr => $chr, start => $start, end => $end, assembly => $assembly, species_id => $species },
            expect => "crispr_pairs_in_region_exonic.txt",
        },
        {
            name => 'exon flanking crispr pairs in region',
            data => { crispr_filter => 'exon_flanking', flank_size => 50, chr => $chr, start => $start, end => $end, assembly => $assembly, species_id => $species },
            expect => "crispr_pairs_in_region_flanking.txt",
        },
    ];
    test_gff('/api/crispr_pairs_in_region', $pairs_test);
}



#pass an arrayref of hashrefs with name, data & expect:
#{ name => '', data => {}, expect => {} },
#this will call the base url and check the return value
sub test_json {
    my ( $url_base, $tests ) = @_;

    #my ( $id ) = $url_base =~ ?/([^/]+)$?; #pull out the last word after /

    for my $item ( @{ $tests } ) {
        #use my injected error_ok method if error is in the name cause that means we WANT an error 400/500
        my $method = ( $item->{name} =~ /error/ ) ? 'error_ok' : 'get_ok';

        $test->mech->$method( $test->get_uri($url_base, $item->{data}), 'Can get '.$item->{name} );

        # if ( $item->{name} eq 'PRSS3 exons' ) {
        #     print Dumper( from_json( $test->mech->content ) );
        # }

        is_deeply(
            from_json( $test->mech->content ),
            $item->{expect},
            $item->{name} . " value as expected ($url_base)"
        );
    }
}

sub test_gff {
    my ( $url_base, $tests ) = @_;

    for my $item ( @{ $tests } ) {
        #use my injected error_ok method if error is in the name cause that means we WANT an error 400/500
        my $method = ( $item->{name} =~ /error/ ) ? 'error_ok' : 'get_ok';

        $test->mech->$method( $test->get_uri($url_base, $item->{data}), 'Can get '.$item->{name} );

        my $expected_gff_path = $test->data_folder->file($item->{expect});
        open (my $fh, "<", $expected_gff_path) or die "Cannot open $expected_gff_path - $!";
        my %expected = map { $_ => 1 } grep { chomp $_ } <$fh>;
        my %got = map { $_ => 1 } (split "\n", $test->mech->content);

        is_deeply(
            \%got,
            \%expected,
            $item->{name} . " gff response as expected ($url_base)"
        );
    }
}

#crispr_search
#this isn't actually used as all we care about is pairs. the tests are here, if we do
# {
#     my $tests = [
#         { name => 'empty exons error', data => {}, expect => { error => "Error: Exon_id[] is required" } },
#         {
#             name   => 'invalid exon error',
#             data   => { 'exon_id[]' => 'ENSE0' },
#             expect => { error => "Invalid exon id" }
#         },
#         {
#             name   => 'exon with no crisprs',
#             data   => { 'exon_id[]' => 'ENSE00001382843' },
#             expect => { ENSE00001382843 => [] }
#         },
#         {
#             name   => 'single exon crisprs',
#             data   => { 'exon_id[]' => 'ENSMUSE00000578254' },
#             expect => get_single_exon_crisprs_expected(),
#         },
#         {
#             name   => 'multiple exon crisprs',
#             data   => { 'exon_id[]' => [ qw( ENSMUSE00000109902 ENSMUSE00000758105 ) ] },
#             expect => get_multiple_exon_crisprs_expected(),
#         }
#     ];

#     test_json( '/api/crispr_search', $tests );
# }


