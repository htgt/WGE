package WGE::View::Web;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::View::Web::VERSION = '0.005';
}
## use critic

use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,
    WRAPPER => 'wrapper.tt',
);

=head1 NAME

WGE::View::Web - TT View for WGE

=head1 DESCRIPTION

TT View for WGE.

=head1 SEE ALSO

L<WGE>

=head1 AUTHOR

Anna Farne

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
