package WGE::Controller::Root;

use Moose;
use namespace::autoclean;
use Data::Dumper;
use Try::Tiny;
use Bio::Perl qw( revcom_as_string );
use WGE::Util::CreateDesign;
use WGE::Util::Statistics qw( human_ot_distributions );
use WGE::Util::OffTargetServer;
use WGE::Controller::API qw( handle_public_api );
use JSON;
use LIMS2::REST::Client;

use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' }

has lims2_api => (
    is         => 'ro',
    isa        => 'LIMS2::REST::Client',
    lazy_build => 1
);

sub _build_lims2_api {
    return LIMS2::REST::Client->new_with_config();
}
#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

WGE::Controller::Root - Root Controller for WGE

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $messages;
    try {
        $messages = WGE::Controller::API::handle_public_api();
    } catch {
        $c->log->debug("Unable to connect to LIMS2");
    };
    print Dumper $messages;
    if ($messages) {
        $messages = decode_json $messages;
        print Dumper $messages;
        my @high = @{$messages->{high}};
        my @normal = @{$messages->{normal}};
        $c->stash(
            high => \@high,
            normal => \@normal,
        );
    }
    return;
}

sub about :Path('/about') :Args(0) {
    my ( $self, $c ) = @_;

    return;
}

sub find_crisprs :Path('/find_crisprs') :Args(0) {
    my ( $self, $c ) = @_;

    my @species = sort { $a->{display_name} cmp $b->{display_name} }
                      map { $_->as_hash }
                          $c->model('DB')->resultset('Species')->search( { active => 1 } );

    $c->stash(
        species => \@species,
    );

    return;
}

sub gibson_designer :Path('/gibson_designer') :Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->request->params->{species} ) {
        my $species = $c->request->params->{species};
        $c->session->{species} = $species;
        $c->go( "gibson_design_gene_pick/$species" );
    }

    return;
}

sub crispr_help :Path('/crispr_help') :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash( ot_distributions => human_ot_distributions() );

    return;
}

sub gibson_help :Path('/gibson_help') :Args(0) {
    my ( $self, $c ) = @_;

    return;
}

sub developer_help :Path('/developer_help') :Args(0) {
    my ( $self, $c ) = @_;
    my @species = sort { $a->{display_name} cmp $b->{display_name} }
          map { $_->as_hash }
          $c->model('DB')->resultset('Species')->search( { active => 1 } );
    $c->stash( species => \@species );
    return;
}

sub cell_line_help :Path('/cell_line_help') :Args(0) {
    my ( $self, $c ) = @_;
    return;
}

sub contact :Path('/contact') :Args(0){
    my ( $self, $c ) = @_;

    return;
}

sub search_by_seq :Path('/search_by_seq') :Args(0) {
    my ( $self, $c ) = @_;

    my @species = sort { $a->{display_name} cmp $b->{display_name} }
          map { $_->as_hash }
          $c->model('DB')->resultset('Species')->search( { active => 1 } );

    $c->stash( species => \@species );

    #change to has
    # my $ots = WGE::Util::OffTargetServer->new;

    # $c->stash(
    #     data => $ots->search_by_seq( "GTGTCAGTGAAACTTACTCT", 0 )
    # );

    return;
}

sub find_crisprs_id :Path('/find_crisprs_id') :Args(0) {
    my ( $self, $c ) = @_;

    return;
}

sub find_off_targets :Path('/find_off_targets') :Args(0) {
    my ( $self, $c ) = @_;

    my $ots = WGE::Util::OffTargetServer->new;

    $c->stash(
        data => $ots->find_off_targets( 245377736 )
    );

    return;
}

sub find_off_targets_by_seq :Path('/find_off_targets_by_seq') :Args(0) {
    my ( $self, $c ) = @_;

    my @species = sort { $a->{display_name} cmp $b->{display_name} }
                      map { $_->as_hash }
                          $c->model('DB')->resultset('Species')->search( { active => 1 } );

    $c->stash(
        species => \@species,
    );

    return;
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;

    $c->stash(template => '404.tt');

    $c->response->status(404);

    return;
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Anna Farne

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
