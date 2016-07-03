use strict;
use warnings;
use Test::More tests => 3;
use Ref::Util qw<is_arrayref>;

my $array_func = \&is_arrayref;

is(prototype($array_func), '$', 'is_arrayref has "$" prototype');

# We have to use string eval for this, because when the custom op is being
# used, we expect the direct calls to fail at compile time
my @cases = (
    [is_arrayref => 'is_arrayref([], 17)',
     'direct array call with too many arguments'],
    [is_arrayref => '$array_func->([], 17)',
     'array call through coderef with too many arguments'],
);

for my $case (@cases) {
    my ($name, $code, $desc) = @$case;
    scalar eval $code;
    my $exn = $@;
    like($exn, qr/^(?: \QUsage: Ref::Util::$name(ref)\E
                     | \QToo many arguments for Ref::Util::$name\E\b )/x,
         $desc);
}
