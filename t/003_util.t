use Test::More tests => 2;

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/lib"; #add the test lib

{
    use_ok 'WebAppCommon::Util::EnsEMBL';
    ok my $ens = WebAppCommon::Util::EnsEMBL->new( species => "Mouse" ), 'Can create EnsEMBL instance';

    #should add tests to check we can query adaptors
}

