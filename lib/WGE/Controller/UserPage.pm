package WGE::Controller::UserPage;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use List::MoreUtils qw(any);
use List::Util qw(min max);

BEGIN { extends 'Catalyst::Controller' }


#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

WGE::Controller::UserPage - Controller for User specific report pages in WGE

=cut

sub my_bookmarks :Path('/my_bookmarks'){
	my ($self, $c) = @_;

	unless ($c->user){
		$c->stash->{error_msg} = "You must login to view this page";
		return;
	}

    my $bookmarks;
    $bookmarks->{'Human'}->{crisprs}      = [map { $_->as_hash } $c->user->human_crisprs];
    $bookmarks->{'Human'}->{crispr_pairs} = [map { $_->as_hash({ get_status => 1}) } $c->user->human_crispr_pairs];
    $bookmarks->{'Mouse'}->{crisprs}      = [map { $_->as_hash } $c->user->mouse_crisprs];
    $bookmarks->{'Mouse'}->{crispr_pairs} = [map { $_->as_hash({ get_status => 1}) } $c->user->mouse_crispr_pairs];

    my $regions = _regions_of_interest($c,$bookmarks);

    $c->stash(
    	bookmarks => $bookmarks,
    	regions   => $regions,
    );
=head


    	designs => [map { $_->as_hash } $c->user->designs],
    	design_attempts => [map { $_->as_hash } $c->user->design_attempts],
=cut
 $c->log->debug(Dumper($c->stash));
    return;
}

sub _regions_of_interest{
	my ($c,$bookmarks) = @_;

    my $species_chr_region_scores = {};
	foreach my $species("Human","Mouse"){
		$c->log->debug("Finding regions of interest in $species");
		my $chromosome_region_scores = {};
		my %chromosome_locations;
		foreach my $crispr (@{ $bookmarks->{$species}->{crisprs} }){
			$chromosome_locations{$crispr->{chr_name}}{$crispr->{chr_start}}++;
		}
		foreach my $pair (@{ $bookmarks->{$species}->{crispr_pair} }){
			my $left = $pair->left_crispr;
			$chromosome_locations{$left->{chr_name}}{$left->{chr_start}}++;
		}

		foreach my $chromosome (keys %chromosome_locations){
			$c->log->debug("Finding regions of interest in $chromosome");
			my @locations = keys %{ $chromosome_locations{$chromosome} };
			my %region_score;
            my $start = min @locations;
            my $max = max @locations;
            # Make sure we have at least one 1kb region to look at
            unless ($max > $start+1000){ $max = $start+1000 };
            while($start < $max){
            	$c->log->debug("Start: $start");
            	my $end = $start + 1000;
                foreach my $point (@locations){
                	if ($point >= $start and $point <= $end){
                	    $region_score{$start}++ if $point
                    }
                }
                $start+=1000;
            }
            $chromosome_region_scores->{$chromosome} = \%region_score;
		}
		$species_chr_region_scores->{$species} = $chromosome_region_scores;
	}

	return $species_chr_region_scores;
}

1;