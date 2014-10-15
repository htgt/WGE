package WGE::Controller::REST::Crispr;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::REST::Crispr::VERSION = '0.048';
}
## use critic


use Moose;
use Try::Tiny;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

sub crispr : Path( '/api/crispr' ) : Args(0) :ActionClass( 'REST' ) {}

sub crispr_GET {
    my ($self, $c) = @_;

    $c->assert_user_roles('read');

    my $id = $c->req->params->{id};

    #allow one or many crisprs to be searched
    my $crispr;
    if ( ref $id eq 'ARRAY' ) {
        #if its an array find them all and convert them all to hashes
        my @crisprs = $c->model('DB')->resultset('Crispr')->search(
            { id => { -IN => $id } }
        );

        $crispr = [ map { $_->as_hash } @crisprs ];
    } else {
        $crispr = $c->model('DB')->resultset('Crispr')->find(
            { id => $id }
        )->as_hash;

        #we allow this if the user wants to always have an arrayref back
        $crispr = [ $crispr ] if $c->req->param('return_array');
    }

    return $self->status_ok( $c, entity => $crispr );
}

sub crispr_POST {
    my ($self, $c) = @_;

    $c->assert_user_roles('edit');

    my @update_cols = qw(off_targets off_target_summary);

    my $params = $c->req->data;

    my $crispr = $c->model->resultset('Crispr')->find($params->{id});
    my %update_params = map { $_ => $params->{$_} } grep { exists $params->{$_} } @update_cols;

    $crispr->update(\%update_params) or die $!;

    return $self->status_ok( $c, entity => $crispr->as_hash );
}

sub crisprs_by_exon : Path( '/api/crisprs_by_exon' ) : Args(0) :ActionClass( 'REST' ) {}

sub crisprs_by_exon_GET {
    my ( $self, $c ) = @_;

    $c->assert_user_roles('read');

    die "You must provide a species" unless $c->req->param('species');

    my $species_id = $c->model('DB')->resultset('Species')->find( 
        { id => $c->req->param('species') },
    )->numerical_id;

    my $exons = $c->req->param('exons');
    my $flank = $c->req->param('flank') // 0;

    my @exon_ids = ( ref $exons ) ? @{ $exons } : ( $exons );

    my @crisprs;
    for my $exon ( @exon_ids ) {
        for my $crispr ( $c->model('DB')->resultset('Exon')->find( { ensembl_exon_id => $exon } )->crisprs ) {
            my $z = $crispr->as_hash;
            $z->{ensembl_exon_id} = $exon;
            push @crisprs, $z;
        }
    }

    #my @crisprs = map { $_->as_hash } $c->model('DB')->resultset('CrisprByExon')->search(
    #    {},
    #    { bind => [ '{' . join( ",", @exon_ids ) . '}', $flank, $species_id ] }
    #);

    return $self->status_ok( $c, entity => \@crisprs );
}

1;
