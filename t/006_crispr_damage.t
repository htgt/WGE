use Test::More tests => 8;

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/lib"; #add the test lib

use_ok 'Test::WGE'; # Must use this before WGE to ensure test DB connection is used
use_ok 'WGE';
use_ok 'Test::Script';

my $test = Test::WGE->new;

script_compiles('bin/generate_crispr_off_target_primers.pl');
my %options = (
    '--dir'         => '/opt/t87/local/tmp',
    '--crispr-id'   => 342912247, 
    '--species'     => 'mouse',
);
script_runs(['bin/generate_crispr_off_target_primers.pl', %options]); # Successful
%options = (
    '--dir'         => '/opt/t87/local/tmp',
    '--crispr-id'   => 342912247, 
    '--species'     => 'mouse',
    '--file-type'   => 'XLS',
);
script_runs(['bin/generate_crispr_off_target_primers.pl', %options]); # As XLS
#Insert XLS checking
%options = (
    '--dir'         => '/opt/t87/local/tmp',
    '--crispr-id'   => 342912247, 
    '--species'     => 'mouse',
    '--file-type'   => 'CSV',
    '--file-name'   => 'Test',
);
script_runs(['bin/generate_crispr_off_target_primers.pl', %options]); # As CSV with name
#Insert CSV checking
%options = (
    '--dir'         => '/opt/t87/local/tmp',
    '--crispr-id'   => 342912247, 
    '--species'     => 'human',
);
script_runs(['bin/generate_crispr_off_target_primers.pl', %options]); # Incorrect species


