use utf8;
package WGE::Model::Schema::ResultSet::CrisprPair;

use base 'DBIx::Class::ResultSet';
use Try::Tiny;
use feature qw( say );

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

    my $schema = $self->result_source->schema;
    #get all off targets

    my $species_id = $schema->resultset('Species')->find(
        { id => $species }
      )->numerical_id;

    my @crisprs = $schema->resultset('PairsForCrispr')->search(
        {},
        { bind => [ "{$l_crispr_id,$r_crispr_id}", $species_id ] }
    );

    #group the crisprs by chr_name for quicker comparison

    #i couldn't get the sql to return in a nice way so i just process here
    my %data;
    for my $crispr ( @crisprs ) {
        push @{ $data{ $crispr->chr_name } }, $crispr;
    }

    #get instance of FindPairs with off target settings
    my $pair_finder = WGE::Util::FindPairs->new(
        max_spacer  => 1000,
        include_h2h => 1
    );

    #find_pairs on $all{chr_name}, $all{chr_name}

    my @pairs; 
    while ( my ( $chr_name, $crisprs ) = each %data ) {
        #just throw them all onto one array for now, we'll process after
        push @pairs, $pair_finder->find_pairs( $crisprs, $crisprs );
    }

    #
    # TODO: make crispr pair table.
    #   it doesnt exist apparently. find it in the git history of 2.sql
    #   add CHECK( array_length(off_targets) % 2 = 0 )
    #   write the summary.
    #

    my $total = scalar( @pairs );
    my $summary = q/{"total in 1k":"$total"}/;
    #pull out ids, update or create into self->find
    my @all_offs;
    for my $pair ( @pairs ) {
        #find shortest to add to summary, get orientation etc

        #add the ids
        push @all_offs, $pair->left_crispr->id, $pair->right_crispr->id;
    }

    $self->update_or_create(
        {
            left_crispr_id  => $l_crispr_id,
            right_crispr_id => $r_crispr_id,
            off_target_ids  => \@all_offs,
            spacer          => $spacer
        },
        { key => 'crispr_pairs_left_crispr_id_right_crispr_id_key' }
    );
}

1;
