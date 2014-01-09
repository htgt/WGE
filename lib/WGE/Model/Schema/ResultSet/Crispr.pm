use utf8;
package WGE::Model::Schema::ResultSet::Crispr;

use base 'DBIx::Class::ResultSet';

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
}

1;
