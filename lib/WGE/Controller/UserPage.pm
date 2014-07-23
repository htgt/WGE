package WGE::Controller::UserPage;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::UserPage::VERSION = '0.036';
}
## use critic

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

    my $designs_rs = $c->user->designs;
    my $attempts_rs = $c->user->design_attempts;

    my $bookmarks;
    $bookmarks->{'Human'}->{crisprs}      = [map { $_->as_hash } $c->user->human_crisprs];
    $bookmarks->{'Human'}->{crispr_pairs} = [map { $_->as_hash({ get_status => 1}) } $c->user->human_crispr_pairs];
    $bookmarks->{'Human'}->{designs}      = [map { $_->as_hash } $designs_rs->search({ species_id => 'Human' }, { order_by => 'created_at DESC' }) ];
    $bookmarks->{'Human'}->{attempts}     = [map { $_->as_hash({ json_as_hash => 1 }) } $attempts_rs->search({ species_id => 'Human' },  { order_by => 'created_at DESC' } ) ];      
    $bookmarks->{'Mouse'}->{crisprs}      = [map { $_->as_hash } $c->user->mouse_crisprs];
    $bookmarks->{'Mouse'}->{crispr_pairs} = [map { $_->as_hash({ get_status => 1}) } $c->user->mouse_crispr_pairs];
    $bookmarks->{'Mouse'}->{designs}      = [map { $_->as_hash } $designs_rs->search({ species_id => 'Mouse' }, { order_by => 'created_at DESC' }) ]; 
    $bookmarks->{'Mouse'}->{attempts}     = [map { $_->as_hash({ json_as_hash => 1 }) } $attempts_rs->search({ species_id => 'Mouse' }, { order_by => 'created_at DESC' } ) ];   

    $c->stash(
    	bookmarks => $bookmarks,
    );

    return;
}

1;