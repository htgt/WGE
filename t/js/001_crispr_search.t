#!/usr/bin/env perl

use Test::More tests => 6;

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../lib"; #add the test lib

use_ok 'Test::WGE'; # Must use this before WGE to ensure test DB connection is used


use Selenium::Firefox;

use WebAppCommon::Testing::JS qw( setup find_by );

#Scripts
my $find_crisprs = q{
    $("#radio_grch38").prop("checked", true);
    $('#gene').val("BRCA2");
    return 1;
};

my $exons = q{
    return $('.exon_column_td').length;
};

my $sorting = q{
    return $('tr.ots:eq(2) td:eq(0)').text();
};

#Testing

#Log in selenium
my $driver = setup();

find_by($driver, 'id', 'table_view_example');

#Fill page
ok($driver->execute_script($find_crisprs));
find_by($driver, 'xpath', '//select[@id="exons"]/option[text() = "4. ENSE00003659301 (length 109)"]');
find_by($driver, 'id', 'search_crisprs');

$driver->pause(1000);

#Search for exons
my $exon_count = $driver->execute_script($exons);
is ($exon_count, 2, "Number of exons");

find_by($driver, "link_text", "1106710401");

#Check seq sort
my $title = $driver->get_title();
is ($title, "Individual CRISPR Report", "Crispr summary page");
my $crispr = $driver->execute_script($sorting);
is ($crispr, 965657158, "Sort by seq");

#Check for updated sort
find_by($driver, "id", "ot_sort");
$crispr = $driver->execute_script($sorting);
$driver->pause(500);
is ($crispr, 1095257239, "Sort by loc");

#Remember to close your browser handle.
$driver->shutdown_binary;

1;

