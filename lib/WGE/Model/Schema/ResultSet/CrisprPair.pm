use utf8;
package WGE::Model::Schema::ResultSet::CrisprPair;

use base 'DBIx::Class::ResultSet';
use Try::Tiny;
use feature qw( say );
use Log::Log4perl qw( :easy );
use Data::Dumper;

my $DISTANCE = 1000;

#note: this needs re-writing
sub load_from_hash {
    my ( $self, $pairs_yaml, $test ) = @_;
    
    my $schema = $self->result_source->schema;

    while( my ( $id, $pair ) = each %{ $pairs_yaml } ) {
        try {
            #we have ids for this data already
            if ( $test ) {
                $pair{id} = $id;
            }

            $self->create( $pair );
        }
        catch {
            say "Error inserting $id: $_";
        };
    }

    return;

}

#should really be a util method, then we have
#a calc_off_targets on the result that will call the util method with self->l_crispr etc.
sub calculate_off_targets {
    my ( $self, $species, $l_crispr_id, $r_crispr_id, $spacer ) = @_;

    INFO "Finding crispr off targets for $l_crispr_id and $r_crispr_id";

    my $schema = $self->result_source->schema;
    #get all off targets

    my $species_id = $schema->resultset('Species')->find(
        { id => $species }
      )->numerical_id;

    my @crisprs = $schema->resultset('CrisprOffTargets')->search(
        {},
        { bind => [ '{$l_crispr_id,$r_crispr_id]}', $species_id, $species_id  ] }
    );

    INFO "Found " . scalar( @crisprs ) . " crispr off targets";

    #group the crisprs by chr_name for quicker comparison

    #i couldn't get the sql to return in a nice way so i just process here
    my %data;
    for my $crispr ( @crisprs ) {
        push @{ $data{ $crispr->chr_name } }, $crispr;
    }

    INFO "Finding pairs";

    #get instance of FindPairs with off target settings
    my $pair_finder = WGE::Util::FindPairs->new(
        max_spacer  => $DISTANCE,
        include_h2h => 1
    );

    #find_pairs on $all{chr_name}, $all{chr_name}

    my @all_offs; 
    while ( my ( $chr_name, $crisprs ) = each %data ) {
        #just throw all the ids onto one array,
        #when processing you will take 2 off at a time.
        push @all_offs, 
            map { $_->{left_crispr}{id}, $_->{right_crispr}{id} } 
                @{ $pair_finder->find_pairs( $crisprs, $crisprs ) };
    }

    die "Uneven number of pair ids!" unless @all_offs % 2 == 0;

    INFO "Parsing pairs";

    #
    # TODO:
    #   add CHECK( array_length(off_targets) % 2 = 0 ) maybe?
    #   write the summary.
    #   set status to error (-1) on failure
    #

    my $total = scalar( @all_offs );
    my $summary = qq/{"total in $DISTANCE":"$total"}/;

    INFO "Persisting pair";

    $self->update_or_create(
        {
            left_id         => $l_crispr_id,
            right_id        => $r_crispr_id,
            off_target_ids  => \@all_offs,
            spacer          => $spacer,
            species_id      => $species_id,
            status          => 5, #complete
        },
        { key => 'primary' }
    );
}

1;
