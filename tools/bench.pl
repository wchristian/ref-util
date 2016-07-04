use strict;
use warnings;

use Ref::Util qw<is_arrayref is_plain_arrayref is_plain_hashref>;
use Scalar::Util ();
use Dumbbench;

my $bench = Dumbbench->new(
    target_rel_precision => 0.005, # seek ~0.5%
    initial_runs         => 20,    # the higher the more reliable
);

my $max = 1e6;
my $ref = [];
no warnings;
$bench->add_instances(
    Dumbbench::Instance::PerlSub->new(
        name => 'Ref::Util',
        code => sub { Ref::Util::is_plain_arrayref($ref) for ( 1 .. $max ) },
    ),

    Dumbbench::Instance::PerlSub->new(
        name => 'proper reftype()',
        code => sub {
            ref $ref
                && Scalar::Util::reftype($ref) eq 'ARRAY'
                && !Scalar::Util::blessed($ref)
                for ( 1 .. $max );
        },
    ),

    Dumbbench::Instance::PerlSub->new(
        name => 'simple ref()',
        code => sub { ref($ref) eq 'ARRAY' for ( 1 .. $max ) },
    ),
);

$bench->run;
$bench->report;
