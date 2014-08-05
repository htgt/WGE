use Test::More tests => 8;

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
$test->mech->content_contains('Login with Google', 'mech is not logged in');

#check authentication
$test->authenticated_mech->content_contains('My Bookmarks', 'authenticated mech is logged in');
my @dropdowns = $test->authenticated_mech->scrape_text_by_attr( 'class' => 'dropdown-toggle');
my $user_dropdown = grep {$_ =~ /test_user\@gmail\.com/ } @dropdowns;
ok( $user_dropdown, 'user is test_user@gmail.com' );
