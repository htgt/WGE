use Test::More tests => 6;

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/lib"; #add the test lib

use_ok 'WGE';

{
    use_ok 'WGE::Util::EnsEMBL';
    ok my $ens = WGE::Util::EnsEMBL->new( species => "Mouse" ), 'Can create EnsEMBL instance';

    #should add tests to check we can query adaptors
}

{
    #this needs more testing. duh
    use_ok 'WGE::Util::FindCrisprs';
    ok my $crispr_util = WGE::Util::FindCrisprs->new( species => "Human", expand_seq => 0 ), 'create FindCrisprs';

    #ok (! defined $crispr_util->find_crispr_pairs( "ENSMUSE00000276482" )), 'invalid species exon';
    ok my $crispr_data = $crispr_util->find_crispr_pairs( "ENSE00001625216" ), 'Can find crisprs';
}
