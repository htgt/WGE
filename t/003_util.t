use strict;
use warnings;
use Test::More tests => 26;
use Test::Exception;
use Data::Dumper;
use List::MoreUtils qw/zip/;
use FindBin qw( $Bin );
use lib "$Bin/lib"; #add the test lib
use Test::WGE;

{
    use_ok 'WebAppCommon::Util::EnsEMBL';
    ok my $ens = WebAppCommon::Util::EnsEMBL->new( species => "Mouse" ), 'Can create EnsEMBL instance';

    #should add tests to check we can query adaptors
}

sub test_visible_haplotypes {
    my ( $haplotype, $model, $user, @visibility ) = @_;
    my @lines = map { "Hap$_" } 1 .. 3;
    my %expected = zip @lines, @visibility;
    is_deeply { $haplotype->visible_lines($model, $user) }, \%expected,
        sprintf('visible haplotypes for %s',$user->name);
    return;
}

sub test_allowed_haplotypes {
    my ( $haplotype, $model, $user, $chrom, @allowed ) = @_;
    my @lines = map { "Hap$_" } 1 .. 3;
    my %expected = zip @lines, @allowed;
    foreach my $line ( keys %expected ) {
        my $params = {
            line      => $line,
            chr_name  => $chrom,
            chr_start => 1e6,
            chr_end   => 1e6 + 5e3,
        };
        if ( $expected{$line} ) {
            lives_ok { $haplotype->retrieve_haplotypes($model, $user, $params) }
                sprintf('retrieving %s:%s for %s', $line, $chrom, $user->name);
        } else {
            dies_ok { $haplotype->retrieve_haplotypes($model, $user, $params) }
                sprintf('refusing %s:%s for %s', $line, $chrom, $user->name);
        }
    }
    return;
}

{
    use_ok 'WGE::Util::Haplotype';
    ok my $haplotype = WGE::Util::Haplotype->new( species => 'Human' ),
        'Can create Haplotype instance';
    
    ok my $model = Test::WGE->new;
    $model->load_fixtures;
    my ( $guest, $unknown, $known ) = $model->schema->resultset('User')
        ->search({}, { order_by => [ 'id' ] })->all;
    
    test_visible_haplotypes( $haplotype, $model, $guest, qw/1 0 1/);
    test_visible_haplotypes( $haplotype, $model, $unknown, qw/1 1 1/);
    test_visible_haplotypes( $haplotype, $model, $known, qw/1 1 1/);

    test_allowed_haplotypes( $haplotype, $model, $guest, '1', qw/1 0 1/ );
    test_allowed_haplotypes( $haplotype, $model, $guest, 'X', qw/1 0 0/ );
    test_allowed_haplotypes( $haplotype, $model, $unknown, '1', qw/1 1 1/ );
    test_allowed_haplotypes( $haplotype, $model, $unknown, 'Y', qw/1 1 0/ );
    test_allowed_haplotypes( $haplotype, $model, $known, '1', qw/1 1 1/ );
    test_allowed_haplotypes( $haplotype, $model, $known, 'Y', qw/1 1 1/ );
}

