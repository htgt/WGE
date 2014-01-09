#!/usr/bin/env perl

use strict;
use warnings;

use feature qw( say );

use YAML::Any qw( DumpFile );
use WGE::Util::FindCrisprs;
use Data::Dumper;

use WGE::Model::DB;

my $DB = WGE::Model::DB->new(); 
   
#say $_->id for random_crisprs( 10 );
#dump_crisprs( random_pairs( 10 ) );
dump_crisprs( test_pairs() );

sub dump_crisprs {
    my ( $pairs ) = @_;

    my ( %pairs_yaml, %crisprs_yaml );
    #for my $pair ( $pairs->all ) {
    for my $pair ( @{ $pairs } ) {
        my $pair_hash = as_hash( $pair );

        $pairs_yaml{ delete $pair_hash->{id} } = $pair_hash;

        for my $crispr ( $pair->left_crispr, $pair->right_crispr ) {
            next if defined $crisprs_yaml{ $crispr->id };

            my $crispr_hash = as_hash( $crispr );
            $crisprs_yaml{ delete $crispr_hash->{id} } = $crispr_hash;
        }
    }

    DumpFile( "pairs.yaml", \%pairs_yaml );
    DumpFile( "crisprs.yaml", \%crisprs_yaml );

    return; 
}

sub random_pairs {
    my ( $num ) = @_;
    return $DB->schema->resultset("CrisprPair")->search_rs({}, { rows => $num });
}

#returns all the pairs we use in our test yaml
sub test_pairs {
    my @ids = qw(
        ENSMUSE00000276482
        ENSMUSE00000276490
        ENSMUSE00000276500
        ENSMUSE00000334714
        ENSMUSE00000363317
        ENSMUSE00000404895
        ENSMUSE00000565000
        ENSMUSE00000565001
        ENSMUSE00000565003
        ENSMUSE00000109898
        ENSMUSE00000109902
        ENSMUSE00000578254
        ENSMUSE00000758105
        ENSMUSE00001224567
        ENSE00001625216
        ENSE00001859079
        ENSE00003298355
        ENSE00003414827
        ENSE00003613028
        ENSE00000780305
        ENSE00000780306
        ENSE00000826192
        ENSE00000826193
        ENSE00000826194
        ENSE00001214061
        ENSE00001297017
    );

    #ENSE00001382843 - taken out to check empty

    my @exons = $DB->schema->resultset('Exon')->search( { ensembl_exon_id => { -IN => \@ids } } );

    my @pairs;
    for my $exon ( @exons ) {
        my $counter = 0;
        for my $pair ( $exon->pairs ) {
            push @pairs, $pair;

            last if ++$counter >= 1;
        }
    }

    return [ @pairs ];
}

sub as_hash {
    my $object = shift;

    return { map { $_ => $object->$_ } $object->columns };
}

1;