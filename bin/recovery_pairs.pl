#!/usr/bin/env perl
use strict;
use warnings;

use WGE::Model::DB;
use Data::Dumper;
use Text::CSV;
use IO::Handle;
use IO::File;
use WGE::Util::FindPairs;
use Const::Fast;
use Log::Log4perl ':easy';
use feature qw( say );
use YAML::Any;
use List::Util qw( sum );

# hard coded species id of 2 - Mouse
const my $SPECIES_ID => 2;
Log::Log4perl->easy_init( { level => $DEBUG, layout => '%p %m%n' } );

LOGDIE "Usage: loxp_pairs.pl <loci.csv> <individual|pair>" unless @ARGV == 2;

#should be pair or crispr
my $MODE = $ARGV[1];
die "Mode must be 'individual' or 'pair'" unless $MODE eq 'individual' or $MODE eq 'pair';

my $w = WGE::Model::DB->new;
my $pair_finder = WGE::Util::FindPairs->new( schema => $w->schema );

my $csv = Text::CSV->new();
open ( my $fh, '<', $ARGV[0] ) or die( "Can not open $ARGV[0] " . $! );
# input csv file must have column headers
$csv->column_names( @{ $csv->getline( $fh ) } );

my @output_column_names = $csv->column_names;

#add the column names we want

my @region_groups = qw( loxp cassette ); #this shuold be loxp cassette/pre post/whatever
my %fields = ( chr_name => '', chr_start => '', chr_end => '' );
my @crispr_fields = qw( crispr_id region seq summary );

for my $prefix ( @region_groups ) {
    #pair creates fields like loxp_left_crispr_id
    #crispr creates fields like loxp_crispr_id, loxp_crispr_region
    my @directions = ( $MODE eq 'pair' ) ? qw( left right ) : qw( crispr1 crispr2 );

    #for every 'direction' add a column
    for my $dir ( @directions ) {
        push @output_column_names,
            map { join "_", $prefix, $dir, $_ }
                @crispr_fields;
    }

    #add all the score fields
    #push @output_column_names, map { $prefix . "_" . $_ } qw( score );

    #add spacer and score to the end if its pair
    if ( $MODE eq 'pair' ) {
        push @output_column_names, map { $prefix . "_" . $_ } qw( spacer );
    }

}

#my $output_crisprs_fh = IO::File->new( 'loxp_crispr_ids.txt' , 'w' );
my $output_fh = IO::File->new( "loxp_crispr_report_$MODE.csv" , 'w' );
my $output_csv = Text::CSV->new( { eol => "\n" } );
$output_csv->print( $output_fh, \@output_column_names  );

#fields in this list will be extracted and crisprs found for their regions,
#so there must be a _start, _end and _chr for each entry.


my $line = 0;
while ( my $data = $csv->getline_hr( $fh ) ) {
    DEBUG "Processing line " . ++$line;
    for my $prefix ( @region_groups ) {
        #pull out all the required fields for this category
        for my $suffix ( keys %fields ) {
            my $name = $prefix . "_" . $suffix;

            #make sure the field is present
            $fields{$suffix} = $data->{$name} or die "$name doesn't exist";
        }

        my $crisprs = crisprs_for_region( \%fields );
        my $pairs   = crispr_pairs_for_region( $crisprs, $fields{chr_start}, $fields{chr_end} );

        if ( $MODE eq 'pair' ) {
            #print ids of crisprs without off target data
            say $_->{id} for grep { ! $_->{off_target_summary } }
                map { $_->{left_crispr}, $_->{right_crispr} }
                    @{ $pairs };
            #next;

            my @sorted = rank_pairs( $pairs );

            unless ( @sorted ) {
                DEBUG "Found no pairs for " . region_str( \%fields );
                next;
            }

            my $best_pair = $sorted[0]; #has two keys: score, pair

            add_pair_data( $data, $best_pair, $prefix );
        }
        elsif ( $MODE eq 'individual' ) {
            #get only crisprs inside the target region
            my @valid_crisprs =
                grep { crispr_in_target_region( $_, $fields{chr_start}, $fields{chr_end} ) }
                    map { $_->as_hash }
                        @{ $crisprs };

            say $_->{id} for grep { ! $_->{off_target_summary} } @valid_crisprs;
            #next;

            my @sorted = rank_crisprs( \@valid_crisprs );

            unless ( @sorted ) {
                DEBUG "Found no crisprs for " . region_str( \%fields );
                next;
            }

            my $best_crispr = $sorted[0];
            my $idx = 1;
            # while ( crisprs_overlap( $best_crispr->{crispr}, $sorted[$idx]->{crispr} ) ) {
            #     die "Couldn't find 2 non overlapping crispsr" if ++$idx >= @sorted;
            # }

            add_crispr_data( $data, $best_crispr->{crispr}, $prefix . "_crispr1" );
            add_crispr_data( $data, $sorted[$idx]->{crispr}, $prefix . "_crispr2" );
            #add on the crispr score
            #$data->{"${prefix}_score"} = $best_crispr->{score};
        }
    }

    $output_csv->print( $output_fh, [ @{ $data }{ @output_column_names } ] );


}

=head1 add_pair_data

Add pair fields from best_pair to the data hashref, using
the add_crispr_method for both left and right crisprs.
best_pair is a hashref with two keys: pair, score

=cut
sub add_pair_data {
    my ( $data, $best_pair, $prefix ) = @_;

    #add fields to the csv hash
    for my $dir ( qw( left right ) ) {
        my $crispr = $best_pair->{pair}{"${dir}_crispr"};

        #left and right need a different prefix
        my $crispr_prefix = $prefix . "_" . $dir;
        add_crispr_data( $data, $crispr, $crispr_prefix );
    }

    $data->{"${prefix}_spacer"} = $best_pair->{pair}{spacer};
    $data->{"${prefix}_score"}  = $best_pair->{score};

    return;
}

=head add_crispr_data

Add crispr fields to a hashref

=cut
sub add_crispr_data {
    my ( $data, $crispr, $prefix ) = @_;

    if ( ! $crispr ) {
        return;
    }

    #replace , with ; as this is just temporary
    (my $ots_summary = $crispr->{off_target_summary}) =~ s/,/;/g;

    $data->{"${prefix}_crispr_id"} = $crispr->{id};
    $data->{"${prefix}_region"}    = region_str( $crispr );
    $data->{"${prefix}_seq"}       = $crispr->{seq};
    $data->{"${prefix}_summary"}   = $ots_summary;

    return;
}

=head crisprs_for_region

Find all the single crisprs in and around the target region.

=cut
sub crisprs_for_region {
    my ( $params ) = @_;

    DEBUG "Getting crisprs for " . region_str( $params );

    # we use 90 because the spaced between the crisprs in a pair can be 50 bases.
    # 50 + the size of 2 crisprs is around 90
    # that should bring back all the possible crisprs we want ( and some we do not want
    # which we must filter out )
    my @crisprs = $w->resultset('Crispr')->search(
        {
            'species_id'  => $SPECIES_ID,
            'chr_name'    => $params->{chr_name},
            # need all the crisprs starting with values >= start_coord
            # and whose start values are <= end_coord
            'chr_start'   => {
                -between => [ $params->{chr_start} - 90, $params->{chr_end} + 90 ],
            },
        },
    )->all;

    return \@crisprs;
}

=head crispr_pairs_for_region

Identifies valid pairs within the list of crisprs for the region

=cut
sub crispr_pairs_for_region {
    my ( $crisprs, $loxp_start, $loxp_end ) = @_;

    # Find pairs amongst crisprs
    my $pairs = $pair_finder->find_pairs( $crisprs, $crisprs, { species_id => $SPECIES_ID, get_db_data => 0  } );

    return validate_crispr_pairs( $pairs, $loxp_start, $loxp_end );
}

=head validate_crispr_pairs

The crispr pair is valid if one or both of its crisprs lies within
the target region ( loxp site )

=cut
sub validate_crispr_pairs {
    my ( $pairs, $start, $end ) = @_;
    my @validated_pairs;

    for my $pair ( @{ $pairs } ) {
        if (   crispr_in_target_region( $pair->{left_crispr}, $start, $end )
            || crispr_in_target_region( $pair->{right_crispr}, $start, $end ) )
        {
            push @validated_pairs, $pair;
        }
    }

    return \@validated_pairs;
}

=head crispr_in_target_region

Crispr is in target region if the at least one base of the pam site is within
the target region.

=cut
sub crispr_in_target_region {
    my ( $crispr, $start, $end ) = @_;

    if ( $crispr->{pam_right} ) {
        #we let the crispr go off the end a bit as it will still be disrupted
        #the line is the boundary
        #REGION|NNNNNNGG
        if ( $crispr->{chr_end} > $start && $crispr->{chr_end} <= ($end+8) ) {
            return 1;
        }
    }
    else {
        #CCNNNNNN|REGION
        if ( $crispr->{chr_start} >= ($start-8) && $crispr->{chr_start} < $end ) {
            return 1;
        }
    }

    return;
}

sub rank_pairs {
    my ( $pairs ) = @_;

    my @ranked;
    for my $pair ( @{ $pairs } ) {
        my $left_score  = score_off_target_summary( $pair->{left_crispr}{off_target_summary} );
        my $right_score = score_off_target_summary( $pair->{right_crispr}{off_target_summary} );

        my $pair_score = $left_score + $right_score;

        push @ranked, { score => $pair_score, pair => $pair };
    }

    return sort { $a->{score} <=> $b->{score} } @ranked;
}

sub rank_crisprs {
    my ( $crisprs ) = @_;

    my @ranked;
    for my $crispr ( @{ $crisprs } ) {
        my $score = score_off_target_summary( $crispr->{off_target_summary} );

        push @ranked, { score => $score, crispr => $crispr };
    }

    return sort { $a->{score} <=> $b->{score} } @ranked;
}

sub score_off_target_summary {
    my ( $text ) = @_;

    die "off_target_summary is null" unless $text;

    #load yaml string
    my $summary = Load( $text );

    #the higher the number of mismatches the less weight it should have
    my @weights = ( 100, 50, 10, 1 );

    #get score by adding 0 + 1 + 2 + 3 fields
    return sum map { $summary->{$_} * $weights[$_] } 0 .. 3;
}

sub region_str {
    my $crispr = shift;

    unless ( $crispr->{chr_name} && $crispr->{chr_start} && $crispr->{chr_end} ) {
        die Dumper( $crispr );
    }

    return $crispr->{chr_name} . ':' . $crispr->{chr_start} . '-' . $crispr->{chr_end};
}

sub crisprs_overlap {
    my ( $crispr_1, $crispr_2 ) = @_;

    if ( $crispr_1->{chr_start} >= $crispr_2->{chr_start}
        && $crispr_1->{chr_start} <= $crispr_2->{chr_end} ) {
        return 1;
    }

    if ( $crispr_1->{chr_end} >= $crispr_2->{chr_start}
        && $crispr_1->{chr_end} <= $crispr_2->{chr_end} ) {
        return 1;
    }

    return;
}

=head1 NAME

recovery_pairs.pl - find groups of crisprs pairs in loxp regions

=head1 SYNOPSIS

recovery_pairs.pl [input_file] <individual|pair>

Find crispr pairs for loxp regions of conditional mouse designs

Example usage:

recovery_pairs.pl test.csv individual > test_with_crisprs.csv

Input must be a csv file which has the following columns ( csv file must have column headers ):
loxp_start
loxp_end
chr_name

=head1 DESCRIPTION

This is a modified version of loxp_pairs.pl with slightly more flexibility in what fields can be used to find CRISPRs. The @region_groups array at the top is combined with @directions, which determines the field names. @directions is set to left and right for pair mode and set to crispr1 and crispr2 in individual.

The following arrays:
my @region_groups = qw( loxp cassette );
my @directions = qw( crispr1 crispr2 );

will produce the following fields:
loxp_crispr1, loxp_crispr2, cassette_crispr1, cassette_crispr2

Each crispr also has the fields described in the crispr_fields array added. The names in this array should correspond to key names in a crispr hash, e.g. 
my @crispr_fields = qw( crispr_id region seq summary );

the @region_groups array is also combined with the %fields hash to decide which fields to find region data from, so:

my @region_groups = qw( loxp cassette );
my %fields = ( chr_name => '', chr_start => '', chr_end => '' );

will look for the following fields:

loxp_chr_name, loxp_chr_start, loxp_chr_end, cassette_chr_name, cassette_chr_start, cassette_chr_end

and if they do not exist in your input csv it will give an error.

After these regions have been extracted from your CSV the script will find CRISPRs within that region, defined by whatever rules are in crispr_in_target_region (currently 1 base of the PAM must be inside the region on one end, and can go past the target region on the other end by 8 bases. 

The CRISPRs are then ranked and the top 2 for every region extract in individual mode, or the top pair taken in pair mode.

All CRISPR sites must have off targets or the script will fail. If there are many CRISPR sites without off targets, uncomment the 'next' statement in the main loop after the following line:
say $_->{id} for grep { ! $_->{off_target_summary} } @valid_crisprs;

this will skip any sorting/processing of CRISPRs and will instead just print all the CRISPR IDs that have no off-targets to stdout. Once you have calculated all the off targets 

=cut

