package WGE::Controller::UserPage;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Controller::UserPage::VERSION = '0.048';
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
	my ( $self, $c ) = @_;

	unless ( $c->user ) {
		$c->stash->{error_msg} = "You must login to view this page";
		return;
	}

    my $bookmarks;
    for my $species ( qw( Human Mouse ) ) {
        my @designs  = $c->user->designs->search( { species_id => $species }, { order_by => 'created_at DESC' } );
        my @attempts = $c->user->design_attempts->search( { species_id => $species }, { order_by => 'created_at DESC' } );

        my $data = {
            #can't get crisprs easily like this due to GRCh38
            #crisprs      => [ map { $_->as_hash } $c->user->$crispr_table ],
            #crispr_pairs => [ map { $_->as_hash( { get_status => 1 } ) } $c->user->$pair_table ],
            designs      => [ map { $_->as_hash } @designs ],
            attempts     => [ map { $_->as_hash( { json_as_hash => 1 } ) } @attempts ],
        };

        #hardcoded assembly data to make displaying easier. gross
        if ( $species eq "Human" ) {
            $data->{assembly} = {
                GRCh37 => {
                    crisprs      => [ map { $_->as_hash } $c->user->human_crisprs ],
                    crispr_pairs => [ map { $_->as_hash({ get_status => 1}) } $c->user->human_crispr_pairs ],
                },
                GRCh38 => {
                    crisprs      => [ map { $_->as_hash } $c->user->grch38_crisprs ],
                    crispr_pairs => [ map { $_->as_hash( { get_status => 1 } ) } $c->user->grch38_crispr_pairs ],
                },
            }
        }
        elsif ( $species eq "Mouse" ) {
            $data->{assembly} = {
                GRCm38 => {
                    crisprs      => [ map { $_->as_hash } $c->user->mouse_crisprs ],
                    crispr_pairs => [ map { $_->as_hash( { get_status => 1 } ) } $c->user->mouse_crispr_pairs ],
                },
            };
        }
        else {
            die "Unknown species";
        }

        $bookmarks->{$species} = $data;
    }

    $c->stash(
    	bookmarks => $bookmarks,
    );

    return;
}

1;