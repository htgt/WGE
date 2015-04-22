use Test::More tests => 9;

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/lib"; #add the test lib

use_ok 'Test::WGE'; # Must use this before WGE to ensure test DB connection is used
use_ok 'WGE';

my $test = Test::WGE->new;

#check routes
$test->mech->get_ok( '/', 'a route handler is defined for /' );
$test->mech->get_ok( '/about', 'a route handler is defined for about' );
$test->mech->get_ok( '/contact', 'a route handler is defined for contact' );

#check links on help pages
$test->mech->get_ok('/developer_help','can get developer help');

# Can't do this test as the links refer to things that are not in test fixtures
# TODO: add the required crisprs etc to test fixtures
#my @links = $test->mech->find_all_links( url_regex => qr/api/ );
#$test->mech->links_ok(\@links, 'can get all api links in dev help page');

$test->mech->content_contains('Login with Google', 'mech is not logged in');

#check authentication
$test->authenticated_mech->content_contains('My Bookmarks', 'authenticated mech is logged in');
my @dropdowns = $test->authenticated_mech->scrape_text_by_attr( 'class' => 'dropdown-toggle');
my $user_dropdown = grep {$_ =~ /test_user\@gmail\.com/ } @dropdowns;
ok( $user_dropdown, 'user is test_user@gmail.com' );
