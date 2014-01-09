package WGE::Util::FindCrisprs;

use strict;
use warnings;

use feature qw( say );

use Moose;
use WGE::Util::EnsEMBL;
use Bio::Perl qw( revcom );

has species => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has min_spacer => (
    is => 'rw',
    isa => 'Int',
    required => 1,
    default => '-10'
);

has max_spacer => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
    default  => '30'
);

has expand_seq => (
    is       => 'rw',
    isa      => 'Bool',
    default  => 1,
    required => 1,
);

has ensembl => (
    is         => 'rw',
    isa        => 'WGE::Util::EnsEMBL',
    lazy_build => 1,
    handles    => [ 'gene_adaptor', 'slice_adaptor' ],
);

sub _build_ensembl {
    my $self = shift;

    return WGE::Util::EnsEMBL->new( species => $self->species );
}

has exon_regexes => (
    isa        => 'HashRef',
    traits     => [ 'Hash' ],
    lazy_build => 1,
    handles => {
        valid_species => 'exists',
        exon_re       => 'get'
    }
);

#make sure we get exon ids for the right species
sub _build_exon_regexes {
    return { 'Mouse' => qr/ENSMUSE/, 'Human' => qr/ENSE/ };
}

sub find_crispr_pairs {
    my ( $self, @exon_ids ) = @_;

    say STDERR "No exons provided" unless @exon_ids;

    unless ( $self->valid_species( $self->species ) ) {
        say STDERR $self->species . " is not a valid species. (case sensitive)";
        return;
    }

    my %pairs_by_exon;
    for my $exon_id ( @exon_ids ) {
        if ( $exon_id !~ $self->exon_re( $self->species ) ) {
            say STDERR "$exon_id is not a valid exon for this species!";
            next;
        }

        say STDERR "Finding crisprs in $exon_id";

        #get a slice of just the exon
        my $exon_slice = $self->slice_adaptor->fetch_by_exon_stable_id( $exon_id );
        #say STDERR "Exon length: " .$exon_slice->length;

        #expand the slice if expand_seq is set (it is by default)
        if ( $self->expand_seq ) {        
            #we need the gene so we can get the strand and take an asymmetrical slice:
            # 5' -----[ EXON ]----- 3'
            #      200        100
            my $gene = $self->gene_adaptor->fetch_by_exon_stable_id( $exon_id );
            #say STDERR "Gene identified as " . $gene->external_name;

            #expand the slice considering the strand.
            if ( $gene->strand == 1 ) {
                $exon_slice = $exon_slice->expand( 200, 100 );
            }
            elsif ( $gene->strand == -1 ) {
                $exon_slice = $exon_slice->expand( 100, 200 );
            }
            else {
                die "Unexpected strand for gene associated with $exon_id";
            }
        }

        die "Couldn't get slice" unless $exon_slice;

        #arrayref of pairs
        my $matches = $self->get_matches( $exon_slice );

        #add to the global pairs hash so we can output all data
        $pairs_by_exon{ $exon_id } = $matches;
    }

    return \%pairs_by_exon;
}

sub get_crisprs {
    my ( $self, $pairs_by_exon ) = @_;

    my %unique_crisprs;
    while ( my ( $exon_id, $pairs ) = each %{ $pairs_by_exon } ) {
        $unique_crisprs{ $exon_id } = $self->_get_unique_crisprs( $pairs );
    }

    return \%unique_crisprs;
}

#used to extract only unique crisprs from all the pairs
sub _get_unique_crisprs {
    my ( $self, $pairs ) = @_;

    #create and return a hash of crispr ids pointing to crispr hashrefs
    my %unique;
    for my $pair ( @{ $pairs } ) {
        #first_crisprs have ids ending in A, second_crisprs end in B
        #some crisprs are in both lists (intentionally) -- for those we want
        #both to be in the hash, which is why they have different ids.
        for my $crispr ( qw( first_crispr second_crispr ) ) {
            my $id = $pair->{$crispr}{id};

            #add it if we don't already have it in the hash
            if( ! defined $unique{$id} ) {
                $pair->{$crispr}{pam_right} = ( $id =~ /B$/ ) || 0; #set pam_right to true/false
                $unique{$id} = $pair->{$crispr};
            }
        }
    }

    return \%unique;
}

#high level function to return pairs to put in the db.
#this method should only be called after the crisprs have been inserted into the db so they
#have a db id
sub get_pairs {
    my ( $self, $pairs_by_exon ) = @_;

    #we only want the pair information so we need to strip it out.
    #remember that pair_data is a hash whose keys point to an arrayref of hashrefs, e.g.:
    # ( ENSE0003596810 => [ {pair_hash_ref}, {pair_hash_ref}, ... ] )
    my @db_pairs;

    while ( my ( $exon_id, $pairs ) = each %{ $pairs_by_exon } ) {
        #for every pair in this exon make a hashref of pair data.
        for my $pair ( @{ $pairs } ) {
            #make sure we have db ids
            unless ( $pair->{first_crispr}{db_id} && $pair->{second_crispr}{db_id}  ) {
                die "get_pairs must be called after crisprs are persisted.";
            }

            push @db_pairs, {
                left_crispr_id  => $pair->{first_crispr}{db_id},
                right_crispr_id => $pair->{second_crispr}{db_id},
                spacer          => $pair->{spacer_length},
            };

        }
    }

    return \@db_pairs;
}

sub get_matches {
    my ( $self, $slice ) = @_;

    my $seq = $slice->seq;

    my ( @pam_left, @pam_right );

    my $id = 1;

    #say STDERR "Slice location:" . $slice->start . "-" . $slice->end . " (" . ($slice->length) . "bp)";

    while ( $seq =~ /(CC\S{21}|\S{21}GG)/g ) {
        my $crispr_seq = $1;

        my $data = {
            chr_start => $slice->start + ((pos $seq) - length( $crispr_seq )), #is this right? i hope so
            chr_end   => $slice->start + ((pos $seq) - 1), #need to subtract 1 or we get 24bp sequence back
            chr_name  => $slice->seq_region_name, #the same for all of them but we need it for the db
            id        => $id++, #used to identify crisprs to add off targets later
            seq       => $crispr_seq,
        };

        my $type;

        #determine the direction, name appropriately and add to the correct list.
        if ( $crispr_seq =~ /^CC.*GG$/ ) {
            #its left AND right. what a joke
            $type = "both ";
            #note that they still both point to the same locus, because why would you change that??
            my $right_data = { %$data }; #shallow copy data so they can be edited separately 
            $data->{id}       .= "A"; #pretend this is called left_data in this block
            $right_data->{id} .= "B";

            push @pam_left, $data;
            push @pam_right, $right_data;
        }
        elsif ( $crispr_seq =~ /^CC/ ) {
            $type = "left ";
            $data->{id} .= "A";

            push @pam_left, $data;
        }
        elsif ( $crispr_seq =~ /GG$/ ) {
            $type = "right";
            $data->{id} .= "B";

            push @pam_right, $data;
        }
        else {
            die "Crispr doesn't have a valid PAM site.";
        }

        #say STDERR "Found $type crispr " . $data->{id} . ": $crispr_seq\@" . $slice->seq_region_name . ":"
        #                                                . $data->{chr_start} . "-" 
        #                                               . $data->{chr_end} . ":"
        #                                               . $slice->strand;

        #go back to just after the pam site so we can find overlapping crisprs
        pos($seq) -= length( $crispr_seq ) - 1;
    }

    #say STDERR "Found " . scalar(@pam_left) . " left crisprs and " . scalar(@pam_right) . " right crisprs";

    return $self->_get_pairs( \@pam_left, \@pam_right );
}

#internal method to find all pairs given left and right crisprs
sub _get_pairs {
    my ( $self, $pam_left, $pam_right ) = @_;

    my @pairs;

    #compare every left/right possibility, and see if they're a valid pair

    for my $l ( @{ $pam_left } ) {
        for my $r ( @{ $pam_right } ) {
            #take one off because we want the distance BETWEEN the two only.
            my $distance = ($r->{ chr_start } - $l->{ chr_end }) - 1;
            #if ( $distance <= $self->max_spacer && $distance >= $self->min_spacer ) {
            if ( $distance == 30 ) { #temp
                push @pairs, {
                    first_crispr  => $l,
                    spacer_length => $distance,
                    second_crispr => $r,
                }
            }
        }
    }

    #say STDERR "Found " . scalar( @pairs ) . " pairs.";

    return \@pairs;
}

1;

__END__
