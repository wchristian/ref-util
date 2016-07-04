use strict;
use warnings;

use Hello::World qw<mix>;
use Dumbbench;

my $bench = Dumbbench->new(
    target_rel_precision => 0.0005,    # seek ~0.5%
    initial_runs         => 20,        # the higher the more reliable
);

$bench->add_instances(
    Dumbbench::Instance::PerlSub->new(
        name => 'Ref::Util',
        code => sub { mix( 1, 2, 1 ) },
    ),
);

$bench->run;
$bench->report;
