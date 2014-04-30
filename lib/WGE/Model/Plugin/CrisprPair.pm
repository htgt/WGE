package WGE::Model::Plugin::CrisprPair;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Plugin::CrisprPair::VERSION = '0.014';
}
## use critic


use Moose::Role;

has pair_finder => (
    is         => 'ro',
    isa        => 'WGE::Util::FindPairs',
    lazy_build => 1,
);

sub _build_pair_finder {
    my $self = shift;

    return WGE::Util::FindPairs->new;
}

sub find_or_create_crispr_pair {
    my ( $self, $params ) = @_;

    die "left_id and right_id are required"
        unless defined $params->{left_id} and defined $params->{right_id};

    #make sure ids are numeric
    $params->{left_id} =~ s/[^0-9]//g;
    $params->{right_id} =~ s/[^0-9]//g;

    #if we only got a species name pull up the id
    unless ( defined $params->{species_id} ) {
        if ( exists $params->{species} ) {
            $params->{species_id} = $self->resultset('Species')->find(
                { id       => $params->{species} }
            )->numerical_id;
        }
        else {
            die "species_id or species is required."
        }
    }

    #see if the pair exists already
    my $pair = $self->resultset('CrisprPair')->find( 
        { 
            left_id    => $params->{left_id}, 
            right_id   => $params->{right_id},
            species_id => $params->{species_id},
        }
    );

    my @crisprs;
    if ( $pair ) {
        $self->log->debug( "Pair " . $pair->id . " already exists." );
    } 
    else {
        #the pair doesn't exist so lets create it.
        $self->log->debug( "Creating pair " . $params->{left_id} . "_" . $params->{right_id} );

        #first find the crispr entries so we can check they are a valid pair
        #also include the total number of offs for the CrisprPair method
        @crisprs = $self->resultset('Crispr')->search( 
            {  
                id         => { -IN => [ $params->{left_id}, $params->{right_id} ] },
                species_id => $params->{species_id}
            },
            { 
                '+select' => [
                    { array_length => [ 'off_target_ids', 1 ], -as => 'total_offs' }
                ]
            }
        );

        die "Error locating crisprs" if @crisprs != 2;
        #the pair doesn't exist so create it. note that this is subject to a race condition,
        #we should add locks to the table (david said it's part of select syntax)

        #identify if the chosen crisprs are valid by
        #checking the list of crisprs against itself for pairs
        my $pairs = $self->pair_finder->find_pairs( \@crisprs, \@crisprs );

        die "Found more than one pair??" if @{ $pairs } > 1;

        #we were given a valid pair so let's create it
        $pair = $self->resultset('CrisprPair')->create(
            {
                left_id    => $pairs->[0]{left_crispr}{id},
                right_id   => $pairs->[0]{right_crispr}{id},
                spacer     => $pairs->[0]{spacer},
                species_id => $params->{species_id},
            },
            { key => 'primary' }
        );

        #fetch the row back from the db or we won't have a status id
        $pair->discard_changes;
    }

    return ( $pair, \@crisprs );
}

1;