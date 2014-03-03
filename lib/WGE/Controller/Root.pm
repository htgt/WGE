package WGE::Controller::Root;

use Moose;
use namespace::autoclean;
use Data::Dumper;
use Try::Tiny;
use Bio::Perl qw( revcom_as_string );
use WGE::Util::CreateDesign;

BEGIN { extends 'Catalyst::Controller' }

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

    return;
}

sub find_crisprs :Path('/find_crisprs') :Args(0) {
    my ( $self, $c ) = @_;

    return;
}

sub crispr_help :Path('/crispr_help') :Args(0){
    my ( $self, $c ) = @_;
    
    return;	
}

sub contact :Path('/contact') :Args(0){
    my ( $self, $c ) = @_;
    
    return;	
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
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
