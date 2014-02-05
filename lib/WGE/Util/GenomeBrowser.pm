package WGE::Util::GenomeBrowser;
use strict;
use Data::Dumper;
use warnings FATAL => 'all';


=head1 NAME

WGE::Model::Util::GenomeBrowser

=head1 DESCRIPTION

Copied and adapted from LIMS2

=cut

use Sub::Exporter -setup => {
    exports => [ qw(
        crisprs_for_region
        crisprs_to_gff
        crispr_pairs_for_region
        crispr_pairs_to_gff 
        gibson_designs_for_region
        design_oligos_to_gff
    ) ]
};

use Log::Log4perl qw( :easy );

=head2 crisprs_for_region 

Find crisprs for a specific chromosome region. The search is not design
related. The method accepts species, chromosome id, start and end coordinates.

This method is used by the browser REST api to server data for the genome browser.

dp10
=cut

sub crisprs_for_region {
    my $schema = shift;
    my $params = shift;

    # Chromosome number is looked up in the chromosomes table to get the chromosome_id
    $params->{chromosome_id} = retrieve_chromosome_id( $schema, $params->{species}, $params->{chromosome_number} );

    my $crisprs_rs = $schema->resultset('CrisprLocus')->search(
        {
            'assembly_id' => $params->{assembly_id},
            'chr_id'      => $params->{chromosome_id},
            # need all the crisprs starting with values >= start_coord
            # and whose start values are <= end_coord
            'chr_start'   => { -between => [
                $params->{start_coord},
                $params->{end_coord},
                ],
            },
        },
    );

    return $crisprs_rs;
}

=head crispr_pairs_for_region

Returns a resultset containing the paired Crisprs for the region defined by params.

Individual crisprs for a region on a chromosome must be looked up in the CrisprPair table.
This is done by a join pulling back all the pairs in one go.

=cut

sub crispr_pairs_for_region {
    my $schema = shift;
    my $params = shift;


    $params->{chromosome_id} = retrieve_chromosome_id( $schema, $params->{species}, $params->{chromosome_number} );

    my $crisprs_rs = $schema->resultset('CrisprBrowserPairs')->search( {},
        {
            bind => [
                $params->{start_coord},
                $params->{end_coord},
                $params->{chromosome_id},
                $params->{assembly_id},
            ],
        }
    );


    return $crisprs_rs;
}


=head crisprs_for_region_as_arrayref 

Return and array of hashrefs properly inflated for the browser.
This is suitable for serialisation as JSON.

=cut

sub crisprs_for_region_as_arrayref {
    my $schema = shift;
    my $params = shift;

    my $crisprs_rs = crisprs_for_region( $schema, $params ) ;
    $crisprs_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    my @crisprs;

    while ( my $hashref = $crisprs_rs->next ) {
        push @crisprs, $hashref;
    }

    return \@crisprs;
}

sub retrieve_chromosome_id {
    my $schema = shift;
    my $species = shift;
    my $chromosome_number = shift;

    my $chr_id = $schema->resultset('Chromosome')->find( {
            'species_id' => $species,
            'name'       => $chromosome_number,
        }
    );
    return $chr_id->id;
}

=head crisprs_to_gff

Return a reference to an array of strings.
The format of each string is standard GFF3 - that is hard tab separated fields.

=cut

sub crisprs_to_gff {
    my $crisprs_rs = shift;
    my $params = shift;

    my @crisprs_gff;

    push @crisprs_gff, "##gff-version 3";
    push @crisprs_gff, '##sequence-region lims2-region '
        . $params->{'start_coord'}
        . ' '
        . $params->{'end_coord'} ;
    push @crisprs_gff, '# Crisprs for region '
        . $params->{'species'}
        . '('
        . $params->{'assembly_id'}
        . ') '
        . $params->{'chromosome_number'}
        . ':'
        . $params->{'start_coord'}
        . '-'
        . $params->{'end_coord'} ;

        while ( my $crispr_r = $crisprs_rs->next ) {
            my %crispr_format_hash = (
                'seqid' => $params->{'chromosome_number'},
                'source' => 'LIMS2',
                'type' => 'Crispr',
                'start' => $crispr_r->chr_start,
                'end' => $crispr_r->chr_end,
                'score' => '.',
                'strand' => '+' ,
#                'strand' => '.',
                'phase' => '.',
                'attributes' => 'ID='
                    . 'C_' . $crispr_r->crispr_id . ';'
                    . 'Name=' . 'LIMS2' . '-' . $crispr_r->crispr_id
                );
            my $crispr_parent_datum = prep_gff_datum( \%crispr_format_hash );
            $crispr_format_hash{'type'} = 'CDS';
            $crispr_format_hash{'attributes'} =     'ID='
                    . $crispr_r->crispr_id . ';'
                    . 'Parent=C_' . $crispr_r->crispr_id . ';'
                    . 'Name=' . 'LIMS2' . '-' . $crispr_r->crispr_id . ';'
                    . 'color=#45A825'; # greenish
            my $crispr_child_datum = prep_gff_datum( \%crispr_format_hash );
            push @crisprs_gff, $crispr_parent_datum, $crispr_child_datum ;
        }




    return \@crisprs_gff;
}


=head crispr_pairs_to_gff 
Returns an array representing a set of strings ready for 
concatenation to produce a GFF3 format file.

=cut

sub crispr_pairs_to_gff {
    my $crisprs_rs = shift;
    my $params = shift;

    my @crisprs_gff;

    push @crisprs_gff, "##gff-version 3";
    push @crisprs_gff, '##sequence-region lims2-region '
        . $params->{'start_coord'}
        . ' '
        . $params->{'end_coord'} ;
    push @crisprs_gff, '# Crispr pairs for region '
        . $params->{'species'}
        . '('
        . $params->{'assembly_id'}
        . ') '
        . $params->{'chromosome_number'}
        . ':'
        . $params->{'start_coord'}
        . '-'
        . $params->{'end_coord'} ;

        while ( my $crispr_r = $crisprs_rs->next ) {
            my %crispr_format_hash = (
                'seqid' => $params->{'chromosome_number'},
                'source' => 'LIMS2',
                'type' => 'crispr_pair',
                'start' => $crispr_r->left_crispr_start,
                'end' => $crispr_r->right_crispr_end,
                'score' => '.',
                'strand' => '+' ,
#                'strand' => '.',
                'phase' => '.',
                'attributes' => 'ID='
                    . $crispr_r->pair_id . ';'
                    . 'Name=' . 'LIMS2' . '-' . $crispr_r->pair_id
                );
            my $crispr_pair_parent_datum = prep_gff_datum( \%crispr_format_hash );
            $crispr_format_hash{'type'} = 'CDS';
            $crispr_format_hash{'end'} = $crispr_r->left_crispr_end;
            $crispr_format_hash{'attributes'} =     'ID='
                    . $crispr_r->left_crispr_id . ';'
                    . 'Parent=' . $crispr_r->pair_id . ';'
                    . 'Name=' . 'LIMS2' . '-' . $crispr_r->left_crispr_id . ';'
                    . 'color=#AA2424'; # reddish
            my $crispr_left_datum = prep_gff_datum( \%crispr_format_hash );
            $crispr_format_hash{'start'} = $crispr_r->right_crispr_start;
            $crispr_format_hash{'end'} = $crispr_r->right_crispr_end;
            $crispr_format_hash{'attributes'} =     'ID='
                    . $crispr_r->right_crispr_id . ';'
                    . 'Parent=' . $crispr_r->pair_id . ';'
                    . 'Name=' . 'LIMS2' . '-' . $crispr_r->right_crispr_id . ';'
                    . 'color=#1A8599'; # blueish
#            $crispr_format_hash{'attributes'} = $crispr_r->pair_id;
            my $crispr_right_datum = prep_gff_datum( \%crispr_format_hash );
            push @crisprs_gff, $crispr_pair_parent_datum, $crispr_left_datum, $crispr_right_datum ;
        }


    return \@crisprs_gff;
}

=head prep_gff_datum
given: hash ref of key value pairs
returns: ref to array of tab separated values

The gff format requires hard tab separated list of values in specified fields.
=cut

sub prep_gff_datum {
    my $datum_hr = shift;

    my @data;

    push @data, @$datum_hr{qw/
        seqid
        source
        type
        start
        end
        score
        strand
        phase
        attributes
        /};
    my $datum = join "\t", @data;
    return $datum;
}

=head
Similar methods for design retrieval and browsing
=cut

sub gibson_designs_for_region {
    my $schema = shift;
    my $params = shift;

    my $chromosome_id = get_chromosome_id($schema, $params);

    my $oligo_rs = $schema->resultset('GibsonDesignBrowser')->search( {},
        {
            bind => [
                $params->{start_coord},
                $params->{end_coord},
                $chromosome_id,
                $params->{assembly_id},
            ],
        }
    );


    return $oligo_rs;
}

sub design_oligos_to_gff {
    my $oligo_rs = shift;
    my $params = shift;

    my @oligo_gff;

    push @oligo_gff, "##gff-version 3";
    push @oligo_gff, '##sequence-region lims2-region '
        . $params->{'start_coord'}
        . ' '
        . $params->{'end_coord'} ;
    push @oligo_gff, '# Gibson designs for region '
        . $params->{'species'}
        . '('
        . $params->{'assembly_id'}
        . ') '
        . $params->{'chromosome_number'}
        . ':'
        . $params->{'start_coord'}
        . '-'
        . $params->{'end_coord'} ;

        my $gibson_designs; # collects the primers and coordinates for each design. It is a hashref of arrayrefs. 
        $gibson_designs = parse_gibson_designs( $oligo_rs );
        my $design_meta_data;
        $design_meta_data = generate_design_meta_data ( $gibson_designs );
        # The gff parent is generated from the meta data for the design
        # must do this for each design (as there may be several)
        foreach my $design_data ( keys %$design_meta_data ) {
            my %oligo_format_hash = (
                'seqid' => $params->{'chromosome_number'},
                'source' => 'LIMS2',
                'type' =>  $design_meta_data->{$design_data}->{'design_type'},
                'start' => $design_meta_data->{$design_data}->{'design_start'},
                'end' => $design_meta_data->{$design_data}->{'design_end'},
                'score' => '.',
                'strand' => ( $design_meta_data->{$design_data}->{'strand'} eq '-1' ) ? '-' : '+',
                'phase' => '.',
                'attributes' => 'ID='
                    . 'D_' . $design_data . ';'
                    . 'Name=' . 'D_' . $design_data
                );
            my $oligo_parent_datum = prep_gff_datum( \%oligo_format_hash );
            push @oligo_gff, $oligo_parent_datum;

            # process the components of the design
            $oligo_format_hash{'type'} = 'CDS';
            foreach my $oligo ( keys %{$gibson_designs->{$design_data}} ) {
                $oligo_format_hash{'start'} = $gibson_designs->{$design_data}->{$oligo}->{'chr_start'};
                $oligo_format_hash{'end'}   = $gibson_designs->{$design_data}->{$oligo}->{'chr_end'};
                $oligo_format_hash{'strand'} = ( $gibson_designs->{$design_data}->{$oligo}->{'chr_strand'} eq '-1' ) ? '-' : '+';
                $oligo_format_hash{'attributes'} =     'ID='
                    . $oligo . ';'
                    . 'Parent=D_' . $design_data . ';'
                    . 'Name=' . $oligo . ';'
                    . 'color=' . $gibson_designs->{$design_data}->{$oligo}->{'colour'};
                my $oligo_child_datum = prep_gff_datum( \%oligo_format_hash );
                push @oligo_gff, $oligo_child_datum ;
            }
        }




    return \@oligo_gff;
}


=head parse_gibson_designs
Given and GibsonDesignBrowser Resultset.
Returns hashref of hashrefs keyd on design_id
=cut

sub parse_gibson_designs {
    my $gibson_rs = shift;

    my %design_structure;

    # Note that the result set is ordered first by design_id and then by chr_start
    # so we can rely on all the data for one design to be grouped together
    # and within the group for the oligos to be properly ordered,
    # whether they are on the Watson or Crick strands.

    # When the gff format is generated, 3s, 5s, and Es will be coloured in pairs
    # 5F with 5R, EF with ER, 3F with 3R

    while ( my $gibson = $gibson_rs->next ) {
        $design_structure{ $gibson->design_id } ->
            {$gibson->oligo_type_id} = {
                'design_oligo_id' => $gibson->oligo_id,
                'chr_start' => $gibson->chr_start,
                'chr_end' => $gibson->chr_end,
                'chr_strand' => $gibson->chr_strand,
                'colour'     => gibson_colour( $gibson->oligo_type_id ),
                'design_type' => $gibson->design_type_id,
            };
    }

    return \%design_structure;
}

=head generate_design_meta_data
Given a design_structure hashref provided by the parse_gibson_design method
Returns a design_meta_data hashref containing the start and end coordinates for the entire design

=cut

sub generate_design_meta_data {
    my $gibson_designs = shift;

    my %design_meta_data;
    my @design_keys;

    @design_keys = sort keys %$gibson_designs;

    foreach my $design_key ( @design_keys ) {
        if ( $gibson_designs->{$design_key}->{'3F'}->{'chr_strand'} == 1 ) {
            # calculate length of design on the plus strand
            $design_meta_data{ $design_key } = {
                'design_start' => $gibson_designs->{$design_key}->{'5F'}->{'chr_start'},
                'design_end'   => $gibson_designs->{$design_key}->{'3R'}->{'chr_end'},
                'strand'       => $gibson_designs->{$design_key}->{'5F'}->{'chr_strand'},
                'design_type'  => $gibson_designs->{$design_key}->{'5F'}->{'design_type'},
            };

        }
        else {
            # calculate length of design on the minus strand
            $design_meta_data{ $design_key } = {
                'design_start' => $gibson_designs->{$design_key}->{'3R'}->{'chr_start'},
                'design_end'   => $gibson_designs->{$design_key}->{'5F'}->{'chr_end'},
                'strand'       => $gibson_designs->{$design_key}->{'3R'}->{'chr_strand'},
                'design_type'  => $gibson_designs->{$design_key}->{'5F'}->{'design_type'},
            };
        }
    }

    return \%design_meta_data;
}

sub gibson_colour {
    my $oligo_type_id = shift;

    my %colours = (
        '5F' => '#68D310',
        '5R' => '#68D310',
        'EF' => '#589BDD',
        'ER' => '#589BDD',
        '3F' => '#BF249B',
        '3R' => '#BF249B',
    );
    return $colours{ $oligo_type_id };
}

sub get_chromosome_id{
    my ($schema, $params) = @_;

    my ($species, $chr_id);

    $species = $params->{species};

    if(not defined $species){
        my $assembly = $params->{assembly_id}
            or die "no species or assembly provided to get_chromosome_id";
        $species = $schema->resultset('Assembly')->find({ id => $assembly })->species_id
            or die "Could not find assembly $assembly";
        # Add species to params hash for future use
        $params->{species} = $species;
    }
    
    my $chromosome = $schema->resultset('Chromosome')->find({ name => $params->{chromosome_number}, species_id => $species });
    return $chromosome->id;
}
1;
