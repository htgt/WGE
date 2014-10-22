package WGE::Util::GenomeBrowser;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::GenomeBrowser::VERSION = '0.051';
}
## use critic

use strict;
use Data::Dumper;
use TryCatch;
use Log::Log4perl qw(:easy);
use warnings FATAL => 'all';


BEGIN {
    #try not to override the logger
    unless ( Log::Log4perl->initialized ) {
        Log::Log4perl->easy_init( { level => $DEBUG } );
    }
 }
=head1 NAME

WGE::Model::Util::GenomeBrowser

=head1 DESCRIPTION

Copied and adapted from LIMS2

=cut

use Sub::Exporter -setup => {
    exports => [ qw(
        get_region_from_params
        fetch_design_data
        crisprs_for_region
        crisprs_to_gff
        crispr_pairs_for_region
        crispr_pairs_to_gff
        gibson_designs_for_region
        design_oligos_to_gff
        bookmarked_pairs_for_region
        colours
    ) ]
};

use Log::Log4perl qw( :easy );

=head2 colours

return hashref of colours for various types of features in genoverse

=cut

sub colours {
    # Change left_in_design and right_in_design to show
    # crisprs which overlap a design
    # Using the normal crispr colours for these at the moment
    # as it seems unnecessary to hightlight them
    my %colours = (
        left_crispr     => '#45A825', # greenish
        right_crispr    => '#52CCCC', # bright blue
        left_in_design  => '#45A825', # greenish
        right_in_design => '#52CCCC', # bright blue
        no_ot_summary   => '#B2B2B2', # grey
        pam             => '#1A8599', # blue
        '5F' => '#68D310',
        '5R' => '#68D310',
        'EF' => '#589BDD',
        'ER' => '#589BDD',
        '3F' => '#BF249B',
        '3R' => '#BF249B',
    );
    return \%colours;
}

sub gibson_colour {
    my $oligo_type_id = shift;

    return colours->{ $oligo_type_id };
}

=head2 get_region_from_params

Takes schema and hashref of params (usually from catalyst request) and returns hashref
containing chromosome name and coordinates

Input params can be coordinates etc, WGE design id or exon id or crispr id or crispr pair id

FIXME: need some param validation to return errors to user if e.g. crispr_id is not numerical

af11

=cut

sub get_region_from_params{
    my $schema = shift;
    my $params = shift;

    my @required = qw(genome chromosome browse_start browse_end);
    my @missing_params = grep { not defined $params->{$_ } } @required;

    if (@missing_params){
        if ($params->{'design_id'}){
            # get info for initial display from design oligos...
            my $design_data = fetch_design_data($schema, $params);

            my $species = $params->{species_id}; #optional as we can find it

            my ($start, $end, $chromosome, $genome);
            foreach my $oligo (@{ $design_data->{oligos} || [] }){
                #set the species from the first oligo
                if ( not defined $species ) {
                    my $assembly = $oligo->{locus}{assembly};
                    #we have to hardcode this as there is no db link from assembly
                    # - it will take you to Human.
                    if ( $assembly eq "GRCh38" ) {
                        $species = "Grch38";
                    }
                    else {
                        $species = $schema->resultset('Assembly')->find({ id => $assembly })->species->id;
                    }
                }
                $chromosome ||= $oligo->{locus}->{chr_name};
                $genome   ||= $oligo->{locus}->{assembly};
                my $oligo_start = $oligo->{locus}->{chr_start};
                my $oligo_end = $oligo->{locus}->{chr_end};

                if ($oligo_start > $oligo_end){
                    die "Was not expecting oligo start to be after oligo end";
                }

                if (not defined $start or $start > $oligo_start){
                    $start = $oligo_start;
                }

                if (not defined $end or $end < $oligo_end){
                    $end = $oligo_end;
                }
            }

            return {
                'species'       => $species,
                'genome'        => $genome,
                'chromosome'    => $chromosome,
                'browse_start'  => $start,
                'browse_end'    => $end,
                'design_id'     => $design_data->{id},
                'genes'         => $design_data->{assigned_genes},
            };
        }
        elsif (my $exon_id_list = $params->{'exon_id'}){
            unless ( defined $params->{species_id} ) {
                die "A species must be provided with an ensembl exon id";
            }

            # FIXME: crispr search form can have multiple exons selected
            # just use on of these for now
            my ( $exon_id ) = split ",", $exon_id_list;
            my ( $exon ) = $schema->resultset('Exon')->search(
                {
                    ensembl_exon_id => $exon_id,
                    'species.id'    => $params->{species_id},
                },
                { join => { gene => 'species' } }
            );
            die "Could not find exon $exon_id in WGE database" unless $exon;

            my $genome = $exon->gene->species->assembly;

            return {
                'species'      => $params->{species_id},
                'genes'        => $exon_id,
                'genome'       => $genome,
                'chromosome'   => $exon->chr_name,
                'browse_start' => $exon->chr_start,
                'browse_end'   => $exon->chr_end
            };
        }
        elsif ($params->{'crispr_id'} || $params->{'crispr_pair_id'}){
            my $crispr_id = $params->{'crispr_id'};
            #if we didn't get a crispr id it means its a pair, so take the left crispr id
            unless ( $crispr_id ) {
                ( $crispr_id ) = $params->{'crispr_pair_id'} =~ /^(\d+)_/;
            }

            my $crispr = $schema->resultset('Crispr')->find({ id => $crispr_id })
                or die "Could not find crispr $crispr_id in WGE database";

            my $species = $crispr->species;
            my $genome = $species->assembly;
            # Browse to a 1kb region around the crispr
            return {
                'species'      => $species->id,
                'genome'       => $genome,
                'chromosome'   => $crispr->chr_name,
                'browse_start' => $crispr->chr_start - 500,
                'browse_end'   => $crispr->chr_start + 500,
            }
        }
    }
    else{
        # All region params provided, we just return them
        my %region = map { $_ => $params->{$_} } @required;
        if ($params->{'genes'}){
            $region{'genes'} = $params->{'genes'};
        }
        return \%region;
    }

    die "No region parameters, design_id, exon_id, crispr_id or crispr_pair_id provided";
}

=head fetch_design_data

Takes schema and input params
Attempts to retrieve design_id and returns it as hash

af11

=cut
sub fetch_design_data{
    my ($schema, $params) = @_;

    my $design_id  = $params->{'design_id'};

    my $design;
    try {
        $design = $schema->c_retrieve_design( { id => $design_id } );
    }
    catch( LIMS2::Exception::Validation $e ) {
        die "Please provide a valid design id\n";
    }
    catch( LIMS2::Exception::NotFound $e ) {
        die "Design $design_id not found\n" ;
    }

    my $design_data = $design->as_hash;
    $design_data->{assigned_genes} = join q{, }, @{ $design_data->{assigned_genes} || [] };
    my $design_attempt = $design->design_attempt;
    $design_data->{design_attempt} = $design_attempt->id if $design_attempt;

    TRACE( "Design: " .Dumper($design_data) );

    return $design_data;
}

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
    my $species = $schema->resultset('Species')->find( { id => $params->{species_id} } );
    unless ( $species ) {
        WARN( "Couldn't find species " . $params->{species_id} );
        return;
    }

    # Store species name for gff output
    $params->{species} = $species->id;
    $params->{species_numerical_id} = $species->numerical_id;

    my $user = $params->{user};

    unless($params->{crispr_filter}){ $params->{crispr_filter} = 'all' }

    if ($params->{crispr_filter} eq 'exon_flanking'){

        # default to 100 bp
        my $flank_size = $params->{flank_size} || 100;

        my $genes = _genes_for_region($schema, $params, $species);
        my @exons = map { $_->exons } $genes->all;
        my @region_conditions;
        foreach my $exon (@exons){
             push @region_conditions, { -between => [ $exon->chr_start - $flank_size, $exon->chr_start] };
             push @region_conditions, { -between => [ $exon->chr_end, $exon->chr_end + $flank_size] };
        }
        my $flanking_crisprs_rs = $schema->resultset('Crispr')->search(
            {
                'species_id' => $species->numerical_id,
                'chr_name'   => $params->{chromosome_number},
                'chr_start'  => [ @region_conditions ]
            }
        );
        if($user){ return _bookmarked($user, $flanking_crisprs_rs) };
        return $flanking_crisprs_rs;
    }

    # Default to getting all crisprs in region
    my $search_params = {
            'species_id'  => $species->numerical_id,
            'chr_name'    => $params->{chromosome_number} ,
            # need all the crisprs starting with values >= start_coord
            # and whose start values are <= end_coord
            'chr_start'   => { -between => [
                $params->{start_coord},
                $params->{end_coord},
                ],
            },
        };

    # Add exonic flag filter if applicable
    if($params->{crispr_filter} eq 'exonic'){
        $search_params->{exonic} = 1;
    }

    my $crisprs_rs = $schema->resultset('Crispr')->search($search_params);

    if($user){ return _bookmarked($user, $crisprs_rs) };
    return $crisprs_rs;
}

sub _genes_for_region {
    my $schema = shift;
    my $params = shift;
    my $species = shift;

    # Horrible SQL::Abstract syntax
    # Query is to find any genes which overlap with the region specified
    # i.e. gene start <= region end && region start <= gene end

    my $genes = $schema->resultset('Gene')->search(
        {
            'species_id' => $species->id,
            'chr_name' => $params->{chromosome_number},
            -and => [
                'chr_start' => { '<' => $params->{end_coord} },
                'chr_end'   => { '>' => $params->{start_coord} },
           ],
        },
    );

    return $genes;
}

=head crispr_pairs_for_region

Identifies pairs within the list of crisprs for the region

=cut

sub crispr_pairs_for_region {
    my $schema = shift;
    my $params = shift;

    my $crisprs_rs = crisprs_for_region($schema, $params);

    # NB: crisprs_for_region will add the species and species_numerical_id to $params
    # I should do this in a separate method with sensible name

    my $options = {
        get_db_data => 1,
        species_id  => $params->{species_numerical_id},
        sort_pairs  => $params->{sort_pairs},
    };

    # Find pairs amongst crisprs
    my $pair_finder = WGE::Util::FindPairs->new({ schema => $schema });
    my $pairs = $pair_finder->window_find_pairs($params->{start_coord}, $params->{end_coord}, $crisprs_rs, $options);
    return $pairs;
}

=head bookmarked_pairs_for_region

Retrieves pairs from db that have been bookmarked by user. No fancy pair finding needed for this.

=cut

sub bookmarked_pairs_for_region{
    my $schema = shift;
    my $params = shift;

    # FIXME: this needs to respond to exon and exon-flanking filters

    my $species = $schema->resultset('Assembly')->find({ id => $params->{assembly_id} })->species;

    # Store species name for gff output
    $params->{species} = $species->id;
    $params->{species_numerical_id} = $species->numerical_id;

    my @pairs;

    if ($species->id eq 'Human'){
        @pairs = $params->{user}->human_crispr_pairs;
    }
    elsif($species->id eq 'Mouse'){
        @pairs = $params->{user}->mouse_crispr_pairs;
    }

    my @pairs_in_region;
    foreach my $pair (@pairs){

        next unless $pair->left->chr_name eq $params->{chromosome_number};

        my $start = $pair->left->chr_start;
        my $end = $pair->right->chr_end;

        # Test if crispr pair overlaps with region
        if ( $start <= $params->{end_coord} and $params->{start_coord} <= $end ){
            push @pairs_in_region, $pair;
        }
    }

    my @hashes = map { $_->as_hash({ get_status => 1 }) } @pairs_in_region;

    # Add db_data key to the pair hashes so they resemble
    # those generated by WGE::Util::FindPairs
    foreach my $pair_hash (@hashes){
        my $db_data = {
            off_target_summary => $pair_hash->{off_target_summary},
            status             => $pair_hash->{status},
        };
        $pair_hash->{db_data} = $db_data;
    }
    TRACE Dumper(\@hashes);
    return \@hashes;
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

    my $design_range = _generate_design_range($params);

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
            my $parent_id = 'C_' . $crispr_r->id;
            my %crispr_format_hash = (
                'seqid' => $params->{'chromosome_number'},
                'source' => 'WGE',
                'type' => 'Crispr',
                'start' => $crispr_r->chr_start,
                'end' => $crispr_r->chr_start + 22,
                'score' => '.',
                'strand' => '+' ,
#                'strand' => '.',
                'phase' => '.',
                'attributes' => 'ID='
                    . $parent_id . ';'
                    . 'Name=' . $crispr_r->id
                );

            my $ot_summary = $crispr_r->off_target_summary;
            if($ot_summary){
                TRACE("Found off target summary for crispr ".$crispr_r->id);
                $crispr_format_hash{attributes}.=';OT_Summary='.$ot_summary;
            }

            my $crispr_parent_datum = prep_gff_datum( \%crispr_format_hash );

            # Make 2 different CDS features, one for PAM and
            # one for the crispr without PAM
            $crispr_format_hash{'type'} = 'CDS';
            my $colour = colours->{left_crispr}; # greenish

            if ( defined $design_range ){
                #if ($crispr_r->chr_start > $params->{'design_start'}
                #    and $crispr_r->chr_start < $params->{'design_end'}){
                if ( $crispr_r->chr_start ~~ $design_range){
                    $colour = colours->{left_in_design}; # reddish
                }
            }

            if (not defined $ot_summary){
                $colour = colours->{no_ot_summary}; # grey
            }

            my ($pam_start, $pam_end);
            if($crispr_r->pam_right){
                $crispr_format_hash{'end'} = $crispr_r->chr_end - 2;
                $pam_start =  $crispr_r->chr_end - 2;
                $pam_end = $crispr_r->chr_end;
            }
            else{
                $crispr_format_hash{'start'} = $crispr_r->chr_start + 2;
                $pam_start = $crispr_r->chr_start;
                $pam_end = $crispr_r->chr_start + 2;
            }

            # This is the crispr without PAM
            $crispr_format_hash{'attributes'} =     'ID='
                    . 'Cr_' . $crispr_r->id . ';'
                    . 'Parent=' . $parent_id . ';'
                    . 'Name=' . $crispr_r->id . ';'
                    . 'color=' . $colour;
            my $crispr_child_datum = prep_gff_datum( \%crispr_format_hash );

            # This is the PAM
            $crispr_format_hash{start} = $pam_start;
            $crispr_format_hash{end} = $pam_end;
            $crispr_format_hash{'attributes'} = 'ID='
                    . 'PAM_' . $crispr_r->id . ';'
                    . 'Parent=' . $parent_id . ';'
                    . 'Name=' . $crispr_r->id . ';'
                    . 'color=' . colours->{pam} ;
            my $pam_child_datum = prep_gff_datum( \%crispr_format_hash );

            push @crisprs_gff, $crispr_parent_datum, $crispr_child_datum, $pam_child_datum ;
        }




    return \@crisprs_gff;
}


=head crispr_pairs_to_gff
Returns an array representing a set of strings ready for
concatenation to produce a GFF3 format file.

=cut

sub crispr_pairs_to_gff {
    my $crispr_pairs = shift;
    my $params = shift;

    my @crisprs_gff;

    my $design_range = _generate_design_range($params);

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

        foreach my $crispr_pair (@{ $crispr_pairs || [] } ) {

            my $right = $crispr_pair->{right_crispr};
            my $left = $crispr_pair->{left_crispr};
            my $id = $left->{id}."_".$right->{id};

            my %crispr_format_hash = (
                'seqid' => $params->{'chromosome_number'},
                'source' => 'WGE',
                'type' => 'crispr_pair',
                'start' => $left->{chr_start},
                'end' => $right->{chr_start}+22,
                'score' => '.',
                'strand' => '+' ,
#                'strand' => '.',
                'phase' => '.',
                'attributes' => 'ID='
                    . $id . ';'
                    . 'Name=' . $id .';'
                    . 'Spacer=' . $crispr_pair->{spacer}
                );

            # Add paired OT summary information if pair has data in DB
            if(my $data = $crispr_pair->{db_data}){
                TRACE("Found db_data for crispr pair ".$id);
                if(defined $data->{off_target_summary}){
                    $crispr_format_hash{attributes}.=';OT_Summary='.$data->{off_target_summary};
                }
                elsif(defined $data->{status}){
                    $crispr_format_hash{attributes}.=';OT_Summary=Status: '.$data->{status};
                }
                else{
                    DEBUG("No paired off target summary or status found");
                }
            }

            my $left_colour = colours->{left_crispr};
            my $right_colour = colours->{right_crispr};

            if ( defined $design_range ){
                if ($left->{chr_start} ~~ $design_range){
                    $left_colour = colours->{left_in_design};
                }
                if ($right->{chr_start} ~~ $design_range){
                    $right_colour = colours->{right_in_design};
                }
            }

            # We might have single OT summaries without paired OTs
            my $left_ot = $left->{off_target_summary};
            my $right_ot = $right->{off_target_summary};

            unless($left_ot){
                $left_ot = "not computed";
                $left_colour = colours->{no_ot_summary};
            }

            unless($right_ot){
                $right_ot = "not computed";
                $right_colour = colours->{no_ot_summary};
            }

            $crispr_format_hash{attributes}.=";left_ot_summary=$left_ot;right_ot_summary=$right_ot";

            my $crispr_pair_parent_datum = prep_gff_datum( \%crispr_format_hash );
            push @crisprs_gff, $crispr_pair_parent_datum;

            my $crispr_display_info = {
                left => {
                    crispr => $left,
                    colour => $left_colour,
                },
                right => {
                    crispr => $right,
                    colour => $right_colour,
                }
            };

            foreach my $side ( qw(left right) ){
                my $crispr = $crispr_display_info->{$side}->{crispr};

                my ($pam_start, $pam_end);
                if($crispr->{pam_right}){
                    $crispr_format_hash{'start'} = $crispr->{chr_start};
                    $crispr_format_hash{'end'} = $crispr->{chr_end} - 2;
                    $pam_start =  $crispr->{chr_end} - 2;
                    $pam_end = $crispr->{chr_end};
                }
                else{
                    $crispr_format_hash{'start'} = $crispr->{chr_start} + 2;
                    $crispr_format_hash{'end'} = $crispr->{chr_end};
                    $pam_start = $crispr->{chr_start};
                    $pam_end = $crispr->{chr_start} + 2;
                }

                # This is the crispr without PAM
                $crispr_format_hash{'type'} = 'CDS';
                $crispr_format_hash{'attributes'} =     'ID='
                    . $crispr->{id} . ';'
                    . 'Parent=' . $id . ';'
                    . 'Name=' . $crispr->{id} . ';'
                    . 'color=' .$crispr_display_info->{$side}->{colour};
                my $crispr_datum = prep_gff_datum( \%crispr_format_hash );

                # This is the PAM
                $crispr_format_hash{start} = $pam_start;
                $crispr_format_hash{end} = $pam_end;
                $crispr_format_hash{'attributes'} = 'ID='
                        . 'PAM_' . $crispr->{id} . ';'
                        . 'Parent=' . $id . ';'
                        . 'Name=' . $crispr->{id} . ';'
                        . 'color=' . colours->{pam} ;
                my $pam_child_datum = prep_gff_datum( \%crispr_format_hash );

                push @crisprs_gff, $crispr_datum, $pam_child_datum;
            }
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

    my $username = "guest";
    if ($params->{user}){
        $username = $params->{user}->name;
    }

    my $oligo_rs = $schema->resultset('GibsonDesignBrowser')->search( {},
        {
            bind => [
                $params->{start_coord},
                $params->{end_coord},
                $chromosome_id,
                $params->{assembly_id},
                $username,
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
                'source' => 'WGE',
                'type' =>  $design_meta_data->{$design_data}->{'design_type'},
                'start' => $design_meta_data->{$design_data}->{'design_start'},
                'end' => $design_meta_data->{$design_data}->{'design_end'},
                'score' => '.',
                'strand' => ( $design_meta_data->{$design_data}->{'strand'} eq '-1' ) ? '-' : '+',
                'phase' => '.',
                'attributes' => 'ID='
                    . 'D_' . $design_data . ';'
                    . 'Name=' . $design_data
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

sub _generate_design_range{
    my $params = shift;

    my $design_range = undef;

    if (defined $params->{design_start}){
        if ($params->{design_start} < $params->{design_end}){
            $design_range = [$params->{design_start}..$params->{design_end}];
        }
        else{
            $design_range = [$params->{design_end}..$params->{design_start}];
        }
    }

    return $design_range;
}

## Return the list of crisprs filtered to those bookmarked by this user
sub _bookmarked{
    my ($user, $crisprs_rs) = @_;

    my @bookmarked_ids = map { $_->crispr_id } $user->user_crisprs;
    my $bookmarked_rs = $crisprs_rs->search({ id => { -in => \@bookmarked_ids }});

    return $bookmarked_rs
}
1;
