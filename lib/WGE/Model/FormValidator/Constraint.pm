package WGE::Model::FormValidator::Constraint;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::FormValidator::Constraint::VERSION = '0.033';
}
## use critic


=head1 NAME

WGE::Model::FormValidator::Constraint

=head1 DESCRIPTION

Subclass of WebappCommon::FormValidator::Constraint, where the common constraints can be found.
Add WGE specific constraints to this file.
Add constraints that may be used by both LIMS2 and WGE to WebappCommon::FormValidator::Constraint.

=cut

use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends 'WebAppCommon::FormValidator::Constraint';

has '+model' => (
    isa => 'WGE::Model::DB',
);

sub existing_crispr {
    return shift->existing_row( 'Crispr', 'id' );
}

sub existing_crispr_pair {
    return shift->existing_row( 'CrisprPair', 'id' );
}

sub bookmark_action {
	return shift->in_set( 'add', 'remove' );
}
1;
