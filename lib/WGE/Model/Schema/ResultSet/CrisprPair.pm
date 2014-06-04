use utf8;
package WGE::Model::Schema::ResultSet::CrisprPair;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::ResultSet::CrisprPair::VERSION = '0.019';
}
## use critic


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

=head1

Quickly retrieve a hashref of pair data given some pair ids.
Input is a species and an arrayref of ids, output is a hashref

=cut
sub fast_search_by_ids {
    my ( $self, $options ) = @_;

    my $schema = $self->result_source->schema;

    my $ids = "{" . join( ",", @{ $options->{ids} } ) . "}";

    #skip actual off targets because you shouldn't need to get them in bulk
    my $query = <<'EOT';
with ids as (
    select unnest(?::text[]) as id
)
select cp.id, cp.off_target_summary, cp.status_id, status, cp.last_modified from ids 
join crispr_pairs cp on ids.id=cp.id and species_id=?
join crispr_pair_statuses status on cp.status_id=status.id;
EOT

    return $schema->storage->dbh_do(
        sub {
            my ( $storage, $dbh ) = @_;

            return $dbh->selectall_hashref( $query, 'id', undef, $ids, $options->{species_id} );
        }
    );
}

1;
