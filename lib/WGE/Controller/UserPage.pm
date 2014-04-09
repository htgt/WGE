package WGE::Controller::UserPage;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;

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

    $c->stash(
    	bookmarks => $bookmarks,
    );
=head


    	designs => [map { $_->as_hash } $c->user->designs],
    	design_attempts => [map { $_->as_hash } $c->user->design_attempts],
=cut
 $c->log->debug(Dumper($c->stash));
    return;
}

1;