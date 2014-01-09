use strict;
use warnings;

use WGE;

my $app = WGE->apply_default_middlewares(WGE->psgi_app);
$app;

