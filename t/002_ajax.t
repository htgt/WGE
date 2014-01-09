use Test::More import => [ '!pass' ], tests => 34;

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

#all this stuff is now within Test::WGE
#use Dancer qw( :syntax :tests ); #for logging
#use WGE;
#use Test::WWW::Mechanize::Dancer;
#use Dancer::Plugin::DBIC qw( schema );

#move these tests to another file not requiring model stuff
my $test = Test::WGE->new;
$test->load_fixtures; #should be a test in itself

#test fixtures loaded correctly. kind of weird to do it in here to be honest
ok my @genes = $test->schema->resultset('Gene')->all, 'Can get genes';
#is scalar( @genes ), scalar( map { keys %{ $_ }  } values %{ $genes } ), 'Correct number of genes inserted';
is scalar( @genes ), 4, 'Correct number of genes inserted';

ok my @crisprs = $test->schema->resultset('Crispr')->all, 'Can get crisprs';
#is scalar( @crisprs ), scalar( keys %{ $crisprs } ), 'Correct number of crisprs inserted';
is scalar( @crisprs ), 50, 'Correct number of crisprs inserted';

ok my @pairs = $test->schema->resultset('CrisprPair')->all, 'Can get pairs';
#is scalar( @pairs ), scalar( keys %{ $pairs } ), 'Correct number of pairs inserted';
is scalar( @pairs ), 25, 'Correct number of pairs inserted';


#add headers to make the next requests valid ajax
$test->add_ajax_headers;

#
#need to test actual model stuff in separate file too probably
#

#gene_search
{
    my $tests = [
        { name => 'gene name error', data => {}, expect => { error => "Error: Name is required"} },
        { 
            name   => 'gene species error ', 
            data   => { name => 'PRSS3' }, 
            expect => {error => "Error: Species is required"} 
        },
        { name => 'PRSS3 gene', data => { name => 'PRSS3', species => 'Human' }, expect => ["PRSS3"] },
        { 
            name   => 'PRSS3 case insensitive gene', 
            data   => { name => 'pRss3', species => 'Human' }, 
            expect => ["PRSS3"] 
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
            data   => { marker_symbol => 'PRSS3' }, 
            expect => {error => "Error: Species is required"} 
        },
        { 
            name   => 'invalid gene error', 
            data   => { species => 'Mouse', marker_symbol => 'FAKE' }, 
            expect => { error => "No exons found" }
        },
        { 
            name   => 'PRSS3 exons', 
            data   => { species => 'Mouse', marker_symbol => 'Gnai3' }, 
            expect => { 
              transcript => 'ENSMUST00000000001',
              exons => [
                { exon_id => "ENSMUSE00000334714", rank => 1, len => 258, },
                { exon_id => "ENSMUSE00000276500", rank => 2, len => 42, },
                { exon_id => "ENSMUSE00000276490", rank => 3, len => 141, },
                { exon_id => "ENSMUSE00000276482", rank => 4, len => 157, },
                { exon_id => "ENSMUSE00000565003", rank => 5, len => 128, },
                { exon_id => "ENSMUSE00000565001", rank => 6, len => 129, },
                { exon_id => "ENSMUSE00000565000", rank => 7, len => 153, },
                { exon_id => "ENSMUSE00000404895", rank => 8, len => 209, },
                { exon_id => "ENSMUSE00000363317", rank => 9, len => 2036, },
              ]
            }
        },
    ];

    test_json( '/api/exon_search', $tests );
}

#pair_search
{
    my $tests = [
        { name => 'empty exons error', data => {}, expect => { error => "Error: Exon_id[] is required" } },
        {
            name   => 'invalid exon error', 
            data   => { 'exon_id[]' => 'ENSE0' }, 
            expect => { error => "Invalid exon id" }
        },
        {
            name => 'exon with no pairs', 
            data => { 'exon_id[]' => 'ENSE00001382843' }, 
            expect => { ENSE00001382843 => [] }
        },
        {
            name => 'single exon pairs', 
            data => { 'exon_id[]' => 'ENSMUSE00000578254' }, 
            expect => get_single_exon_pairs_expected(),
        },
        {
            name => 'multiple exon pairs', 
            data => { 'exon_id[]' => [ qw( ENSMUSE00000109902 ENSMUSE00000758105 ) ] }, 
            expect => get_multiple_exon_pairs_expected(),
        },
    ];

    test_json( '/api/pair_search', $tests );
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

#tests that have really long data get methods here so you dont have to scroll past loads of stuff
sub get_single_exon_pairs_expected {
    return {
        ENSMUSE00000578254 => [
                                    {
                                      'right_crispr' => {
                                                          'chr_start' => 78348577,
                                                          'chr_end' => 78348599,
                                                          'pam_right' => 1,
                                                          'species' => 'Mouse',
                                                          'chr_name' => '11',
                                                          'seq' => 'CTACTTCGTGGATGACCGGCTGG'
                                                        },
                                      'left_crispr' => {
                                                         'chr_start' => 78348550,
                                                         'chr_end' => 78348572,
                                                         'pam_right' => 0,
                                                         'species' => 'Mouse',
                                                         'chr_name' => '11',
                                                         'seq' => 'CCCGTATGAGACCCAGTCTGACA'
                                                       },
                                      'spacer' => 4
                                    },
                                    {
                                      'right_crispr' => {
                                                          'chr_start' => 78348577,
                                                          'chr_end' => 78348599,
                                                          'pam_right' => 1,
                                                          'species' => 'Mouse',
                                                          'chr_name' => '11',
                                                          'seq' => 'CTACTTCGTGGATGACCGGCTGG'
                                                        },
                                      'left_crispr' => {
                                                         'chr_start' => 78348550,
                                                         'chr_end' => 78348572,
                                                         'pam_right' => 0,
                                                         'species' => 'Mouse',
                                                         'chr_name' => '11',
                                                         'seq' => 'CCCGTATGAGACCCAGTCTGACA'
                                                       },
                                      'spacer' => 4
                                    }
        ]
    };
}

sub get_multiple_exon_pairs_expected {
    return {
'ENSMUSE00000758105' => [
                                    {
                                      'right_crispr' => {
                                                          'chr_start' => 78343542,
                                                          'chr_end' => 78343564,
                                                          'pam_right' => 1,
                                                          'species' => 'Mouse',
                                                          'chr_name' => '11',
                                                          'seq' => 'CGAGGATCTGCGGCCCCGCGAGG'
                                                        },
                                      'left_crispr' => {
                                                         'chr_start' => 78343490,
                                                         'chr_end' => 78343512,
                                                         'pam_right' => 0,
                                                         'species' => 'Mouse',
                                                         'chr_name' => '11',
                                                         'seq' => 'CCCCCTTCCCCTGGCTCCAGCCG'
                                                       },
                                      'spacer' => 29
                                    },
                                    {
                                      'right_crispr' => {
                                                          'chr_start' => 78343542,
                                                          'chr_end' => 78343564,
                                                          'pam_right' => 1,
                                                          'species' => 'Mouse',
                                                          'chr_name' => '11',
                                                          'seq' => 'CGAGGATCTGCGGCCCCGCGAGG'
                                                        },
                                      'left_crispr' => {
                                                         'chr_start' => 78343490,
                                                         'chr_end' => 78343512,
                                                         'pam_right' => 0,
                                                         'species' => 'Mouse',
                                                         'chr_name' => '11',
                                                         'seq' => 'CCCCCTTCCCCTGGCTCCAGCCG'
                                                       },
                                      'spacer' => 29
                                    }
                                  ],
          'ENSMUSE00000109902' => [
                                    {
                                      'right_crispr' => {
                                                          'chr_start' => 78347818,
                                                          'chr_end' => 78347840,
                                                          'pam_right' => 1,
                                                          'species' => 'Mouse',
                                                          'chr_name' => '11',
                                                          'seq' => 'GGGACCTGGACCCCAATGCAGGG'
                                                        },
                                      'left_crispr' => {
                                                         'chr_start' => 78347805,
                                                         'chr_end' => 78347827,
                                                         'pam_right' => 0,
                                                         'species' => 'Mouse',
                                                         'chr_name' => '11',
                                                         'seq' => 'CCCATCAACCGGCGGGACCTGGA'
                                                       },
                                      'spacer' => -10
                                    },
                                    {
                                      'right_crispr' => {
                                                          'chr_start' => 78347818,
                                                          'chr_end' => 78347840,
                                                          'pam_right' => 1,
                                                          'species' => 'Mouse',
                                                          'chr_name' => '11',
                                                          'seq' => 'GGGACCTGGACCCCAATGCAGGG'
                                                        },
                                      'left_crispr' => {
                                                         'chr_start' => 78347805,
                                                         'chr_end' => 78347827,
                                                         'pam_right' => 0,
                                                         'species' => 'Mouse',
                                                         'chr_name' => '11',
                                                         'seq' => 'CCCATCAACCGGCGGGACCTGGA'
                                                       },
                                      'spacer' => -10
                                    }
        ]
    };
}