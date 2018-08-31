package WGE::Model::FormValidator;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::FormValidator::VERSION = '0.119';
}
## use critic


use warnings FATAL => 'all';

use Moose;
use WGE::Exception::Validation;
use WGE::Model::FormValidator::Constraint;
use namespace::autoclean;

extends 'WebAppCommon::FormValidator';

has '+model' => (
    isa => 'WGE::Model::DB',
);

override _build_constraints => sub {
	my $self = shift;
	return WGE::Model::FormValidator::Constraint->new( model => $self->model );
};
=head2 throw

Override parent throw method to use WGE::Exception::Validation.

=cut
override throw => sub {
    my ( $self, $params, $results ) = @_;

    WGE::Exception::Validation->throw(
        params => $params,
        results => $results,
    );
};

1;
