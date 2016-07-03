use strict;
use warnings;
use Test::More tests => 1;
use Ref::Util qw<is_arrayref>;

# Call multiple routines in a single list expression:
my @got = ( is_arrayref([]) );

ok( $got[0], 'got arrayref in list context' );
