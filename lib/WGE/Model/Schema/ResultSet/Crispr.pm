use utf8;
package WGE::Model::Schema::ResultSet::Crispr;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::ResultSet::Crispr::VERSION = '0.089';
}
## use critic


use Moose;
extends 'DBIx::Class::ResultSet';

#this should be merged into crisprs_for_region
sub search_by_loci {
    my ( $self, $obj, $options ) = @_;

    #options is a hashref to pass to dbix class

    die "You must provide an object" unless defined $obj;

    die "Object passed to search_by_loci must have chr_name, chr_start and chr_end methods."
        unless $obj->can('chr_name') && $obj->can('chr_start') && $obj->can('chr_end');

    #$obj should be an object with chr_name, chr_start and chr_end methods,
    #(for example a gene or exon object)

    return $self->search(
        {
            chr_name  => $obj->chr_name,
            chr_start => { '>' => $obj->chr_start },
            chr_end   => { '<' => $obj->chr_end },
        },
        $options
    );
}

=head crisprs_for_region

Find all the single crisprs in and around the target region.

=cut
sub crisprs_for_region {
    my ( $self, $opts ) = @_;

    #$self->log->debug("Getting crisprs for $chr_name:${chr_start}-${chr_end}");

    # we use 90 because the spaced between the crisprs in a pair can be 50 bases.
    # 50 + the size of 2 crisprs is around 90
    # that should bring back all the possible crisprs we want ( and some we do not want
    # which we must filter out )
    return $self->search(
        {
            'species_id'  => $opts->{species_id},
            'chr_name'    => $opts->{chr_name},
            # need all the crisprs starting with values >= start_coord
            # and whose start values are <= end_coord
            'chr_start'   => {
                -between => [ $opts->{chr_start}-22, $opts->{chr_end} ],
            },
        },
    );
}


sub all_pairs {
    my $self = shift;

    #this is bad because pairs fetches the crisprs again. bad
    return map { $_->pairs } $self->all;

    #this might be more efficient but if we're going to do something like this,
    #we may as well do raw sql.

    # my ( @left_crisprs, @right_crisprs );
    # for my $crispr ( $self->all ) {
    #     if ( $crispr->pam_right ) {
    #         push @right_crisprs, $crispr->id
    #     }
    #     else {
    #         push @left_crisprs, $crispr->id;
    #     }
    # }

    #this is awful cause it gets all the crisprs aGAIN
    #will have to grep through $self->all with this resultset
    # return $self->result_source->schema->resultset('CrisprPair')->search( {
    #     -or => [
    #         left_crispr_id  => { -in => \@left_crisprs },
    #         right_crispr_id => { -in => \@right_crisprs }
    #     ],
    # } );
}

sub load_from_hash {
    my ( $self, $crispr_yaml, $test ) = @_;

    while ( my ( $id, $crispr ) = each %{ $crispr_yaml } ) {
        if ( $test ) {
            #for test data we already have the id we want.
            $crispr->{id} = $id;
        }

        $self->create( $crispr );
    }

    return;
}

1;
