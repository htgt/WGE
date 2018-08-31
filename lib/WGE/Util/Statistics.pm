package WGE::Util::Statistics;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::Statistics::VERSION = '0.119';
}
## use critic

use strict;
use Data::Dumper;


=head1 NAME

WGE::Model::Util::Statistics

=head1 DESCRIPTION

Statistics about the data in WGE

=cut

use Sub::Exporter -setup => {
    exports => [ qw(
        human_ot_distributions
        mouse_ot_distributions
    ) ]
};

sub human_ot_distributions{
    return {
        10 => {
          0 => 1,
          1 => 0,
          2 => 0,
          3 => 4,
          4 => 71
        },
        25 => {
          0 => 1,
          1 => 0,
          2 => 0,
          3 => 9,
          4 => 119
        },
        50 => {
          0 => 1,
          1 => 0,
          2 => 1,
          3 => 17,
          4 => 195
        },
        75 => {
          0 => 1,
          1 => 0,
          2 => 3,
          3 => 34,
          4 => 347
        },
    };
}

sub mouse_ot_distributions{
	die "mouse off-target distributions not yet available";
}

1;