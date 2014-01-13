use Test::More tests => 5;

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
