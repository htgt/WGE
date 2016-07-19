package WGE::Controller::CrisprRanking;

use strict;
use Moose;
use Try::Tiny;
use namespace::autoclean;
use Data::Dumper;
use WGE::Util::ScoreCrisprs qw(retrieve_crisprs_as_arrayref score_and_sort_crisprs);
use WGE::Util::OffTargetServer;

use Text::CSV;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

#On navigated to, find OT calculated crisprs in the browser and sort
sub rank_by_off_targets :Path('/crispr_ranking') :Args(0){
    my ( $self, $c) = @_;

    my $loc = $c->req->param('loc');
    my ($crisprs,$params) = retrieve_crisprs_as_arrayref($c, $loc);
    my @sorted_crisprs = score_and_sort_crisprs($crisprs);

    $c->stash(
        sorted => \@sorted_crisprs,
        params => $params,
        view => "1",
    );
    return;
}


__PACKAGE__->meta->make_immutable;
1;
