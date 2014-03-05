package WGE::Model::FormValidator;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::FormValidator::VERSION = '0.005';
}
## use critic


use warnings FATAL => 'all';

use Moose;
use LIMS2::Model::FormValidator::Constraint;
use namespace::autoclean;

extends 'WebAppCommon::FormValidator';

has '+model' => (
    isa => 'WGE::Model::DB',
);

1;
