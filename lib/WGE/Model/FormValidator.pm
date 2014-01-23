package WGE::Model::FormValidator;

use warnings FATAL => 'all';

use Moose;
use LIMS2::Model::FormValidator::Constraint;
use namespace::autoclean;

extends 'WebAppCommon::FormValidator';

has '+model' => (
    isa => 'WGE::Model',
);