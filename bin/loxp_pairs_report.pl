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
use Smart::Comments;

# hard coded species id of 2 - Mouse
const my $SPECIES_ID => 2;
Log::Log4perl->easy_init( { level => $DEBUG, layout => '%p %m%n' } );

LOGDIE "Usage: loxp_pairs_report.pl <loxp_crisprs_report.csv>" unless @ARGV;

my $w = WGE::Model::DB->new;
my $pair_finder = WGE::Util::FindPairs->new( schema => $w->schema );

my $csv = Text::CSV->new();
open ( my $fh, '<', $ARGV[0] ) or die( "Can not open $ARGV[0] " . $! );
# input csv file must have column headers
$csv->column_names( @{ $csv->getline( $fh ) } );

my @output_column_names = $csv->column_names;
push @output_column_names, qw( crisprs pairs crispr_ids pair_ids );

# my $output_crisprs_fh = IO::File->new( 'loxp_crispr_ids.txt' , 'w' );
my $output_fh = IO::File->new( 'loxp_crispr_report_allpairs.csv' , 'w' );
my $output_csv = Text::CSV->new( { eol => "\n" } );
$output_csv->print( $output_fh, \@output_column_names  );

while ( my $data = $csv->getline_hr( $fh ) ) {

    my $crisprs = crisprs_for_region( $data->{chr_name}, $data->{loxp_start}, $data->{loxp_end} );
    my $pairs = crispr_pairs_for_region( $crisprs, $data->{loxp_start}, $data->{loxp_end} );

    my @valid_crisprs = grep{ crispr_in_target_region( $_, $data->{loxp_start}, $data->{loxp_end} ) } map{ $_->as_hash } @{ $crisprs };

    $data->{crisprs} = scalar( @valid_crisprs );
    $data->{pairs} = scalar( @{ $pairs } );
    $data->{crispr_ids} = join ':', map{ $_->{id} } @valid_crisprs;
    $data->{pair_ids} = join ':', map{ $_->{left_crispr}{id} . '_' . $_->{right_crispr}{id} } @{ $pairs };


    # print "PAIRS: ". $data->{pairs} ."\n";

    my @off_pairs;
    my %sort;
    my $i=0;
    ## $pairs
    # print "SCALAR : ". scalar @{ $pairs }."\n";



## TO GET MISSING CRISPRS
    # open (MISSES, '>>misses.txt');

    foreach my $pair (@{ $pairs }) {

        my $yaml = Load($pair->{left_crispr}{off_target_summary});

        ## $pair
        ## $yaml
        # my $score = '';
        if ($yaml) {
            my $score = $yaml->{0} + $yaml->{1} + $yaml->{2} + $yaml->{3};
        
## TO GET MISSING CRISPRS
            # if (!$pair->{left_crispr}{off_target_summary}) {
            #     print MISSES $pair->{left_crispr}{id} ."\n";
            # }
            # if (!$pair->{right_crispr}{off_target_summary}) {
            #     print MISSES $pair->{right_crispr}{id} ."\n";
            # }

            ## $score
            $sort{$i} = $score;

            push (@off_pairs, [
                'left_crispr:',  $pair->{left_crispr}{id},
                $pair->{left_crispr}{chr_name}.':'.$pair->{left_crispr}{chr_start}.'-'.$pair->{left_crispr}{chr_end},
                $pair->{left_crispr}{seq},
                'right_crispr:', $pair->{right_crispr}{id},
                $pair->{right_crispr}{chr_name}.':'.$pair->{right_crispr}{chr_start}.'-'.$pair->{right_crispr}{chr_end},
                $pair->{right_crispr}{seq},
                'spacer:',       $pair->{spacer}, 
                'score:',        $score
            ] );

            $i++;
        }

        # print "EXIT: $i\n";

    }

    ## @off_pairs

    @off_pairs = sort_rank(\%sort, \@off_pairs);


    ## @off_pairs

## $data
## $crisprs
## $pairs
## @valid_crisprs


    # say $output_crisprs_fh $_ for map{ $_->{id} } @valid_crisprs;

    $output_csv->print( $output_fh, [ @{ $data }{ @output_column_names } ] );

    foreach (@off_pairs) {
        $output_csv->print( $output_fh, $_ );
    }

}

close ($output_fh);


make_report_summary();





sub sort_rank {
    my ( $sort_ref, $off_pairs_ref ) = @_;

    ## $sort
    ## $off_pairs
    my %sort = %$sort_ref;

    my @sorted;
    my @off_pairs = @$off_pairs_ref;
    my $i = 0;
    foreach (sort { ($sort{$a} <=> $sort{$b}) } keys %sort) {
        # print "$i:\t$off_pairs[$_]\n";
        $sorted[$i] = $off_pairs[$_];
        $i++;   
    }
    ## @sorted

    return @sorted;
}



=head crisprs_for_region

Find all the single crisprs in and around the target region.

=cut
sub crisprs_for_region {
    my ( $chr_name, $chr_start, $chr_end ) = @_;

    DEBUG("Getting crisprs for $chr_name:${chr_start}-${chr_end}");

    # we use 90 because the spaced between the crisprs in a pair can be 50 bases.
    # 50 + the size of 2 crisprs is around 90
    # that should bring back all the possible crisprs we want ( and some we do not want
    # which we must filter out )
    my @crisprs = $w->resultset('Crispr')->search(
        {
            'species_id'  => $SPECIES_ID,
            'chr_name'    => $chr_name,
            # need all the crisprs starting with values >= start_coord
            # and whose start values are <= end_coord
            'chr_start'   => {
                -between => [ $chr_start - 90, $chr_end + 90 ],
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
        if ( $crispr->{chr_end} > $start && $crispr->{chr_end} <= $end ) {
            return 1;
        }
    }
    else {
        if ( $crispr->{chr_start} >= $start && $crispr->{chr_start} < $end ) {
            return 1;
        }
    }

    return;
}






sub make_report_summary {

    open (INPUT, 'loxp_crispr_report_allpairs.csv');
    open (OUTPUT, '>loxp_crispr_report_summary.csv');

    my $i;
    my %spacer;
    my %score;
    my %left_crispr_str;
    my %right_crispr_str;
    my $old_line = '';
    my $line;

    while ($line = <INPUT>) {

        if ($line =~ m/gene,project,design_id,project_status/ ) {
            chomp $line;
            print OUTPUT $line . ',left_crispr_id,left_region,left_seq,right_crispr_id,right_region,right_seq,spacer,score';
        }
        if ($line =~ m/left_crispr:,([^,]*,[^,]*,[^,]*),right_crispr:,([^,]*,[^,]*,[^,]*),spacer:,([^,]*),score:,([^,]*)/ ) {
            my $left_crispr_str = ','.$1;
            my $right_crispr_str = ','.$2;
            my $spacer = $3;
            my $score =  $4;

            chomp $score;
            $spacer{$i} = $spacer;
            $score{$i} = $score;
            $left_crispr_str{$i} = $left_crispr_str;
            $right_crispr_str{$i} = $right_crispr_str;

            $i++;

        }
        if ( $line =~ m/[^,]*,[^,]*,[\d]*,"/ ) {

            print OUTPUT $old_line;

            if (%score) {
                my $min_score = $score{0};
                my $max_index;
                my $best_spacer_index;
                my $best_index;

                for ( my $j=0; $j<$i; $j++ ) {

                    if ($score{$j} eq $min_score ) {
                        $max_index = $j;
                    }

                }

                my $current_spacer = 9999999;

                for ( my $j=0; $j<=$max_index; $j++ ) {

                    if ($spacer{$j} < $current_spacer && $spacer{$j} >= 0) {
                        $current_spacer = $spacer{$j};
                        $best_index = $j;
                    }
                }    

                if (!defined $best_index) {
                    $current_spacer = -9999999;
                    for ( my $j=0; $j<=$max_index; $j++ ) {

                        if ($spacer{$j} > $current_spacer) {
                            $current_spacer = $spacer{$j};
                            $best_index = $j;
                        }
                    }   
                }

                if ( $score{$best_index} ) {
                    print OUTPUT $left_crispr_str{$best_index} . $right_crispr_str{$best_index} . "," . $spacer{$best_index} . ",". $score{$best_index};
                };

            }

            $old_line = $line;
            chomp $old_line;
            print OUTPUT "\n";
            $i = 0;
            %spacer = ();
            %score = ();
            %left_crispr_str = ();
            %right_crispr_str = ();

        }
    }

    print OUTPUT $old_line;

    if (%score) {
        my $min_score = $score{0};
        my $max_index;
        my $best_spacer_index;
        my $best_index;

        for ( my $j=0; $j<$i; $j++ ) {

            if ($score{$j} eq $min_score ) {
                $max_index = $j;
            }

        }

        my $current_spacer = 9999999;

        for ( my $j=0; $j<=$max_index; $j++ ) {

            if ($spacer{$j} < $current_spacer && $spacer{$j} >= 0) {
                $current_spacer = $spacer{$j};
                $best_index = $j;

            }

        }    

        if (!defined $best_index) {
            $current_spacer = -9999999;
            for ( my $j=0; $j<=$max_index; $j++ ) {

                if ($spacer{$j} > $current_spacer) {
                    $current_spacer = $spacer{$j};
                    $best_index = $j;
                }

            }   

        }

        if ( $score{$best_index} ) {
            print OUTPUT $left_crispr_str{$best_index} . $right_crispr_str{$best_index} . "," . $spacer{$best_index} . ",". $score{$best_index};
        };

    }

    print OUTPUT "\n";

}



=head1 NAME

loxp_pairs_report.pl - creates reports for crispr pairs from a loxp_pairs.pl result file.

=head1 SYNOPSIS

promotor_crisprs_report.pl [input_file]

Find crispr pairs for loxp regions of conditional mouse designs

Example usage:

loxp_pairs_report.pl [input_file]

Input must be a csv file which has the following columns ( csv file must have column headers ):
loxp_start
loxp_end
chr_name

=head1 DESCRIPTION

Finds crispr pairs that cut in the wildtype sequence of the loxp region of conditional designs ( between D5 and D3 ).
Input csv file must have loxp_start, loxp_end and chr_name columns to work out what crisprs hit the region.

Two output file:
 -loxp_crispr_report_allpairs.csv: copy of original csv file, plus extra column added with crispr / crispr pair ids and counts
 -loxp_crispr_report_summary.csv: copy of original csv file with extra columns for the best crispr pair

=cut

