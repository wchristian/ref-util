use strict;
use warnings;
use Test::More;

use constant NO_FORMAT_REFS => ($] < 5.008);

my @cases;
BEGIN {
    my $blessed_glob = do {
        no warnings 'once';
        my $glob = \*FOO;
        bless $glob;
    };

    my $format = do {
        format FH1 =
.
        *FH1{FORMAT};               # this yields undef on 5.6.x
    };

    my $blessed_format = NO_FORMAT_REFS ? undef : do {
        format FH2 =
.
        my $ref = *FH2{FORMAT};
        bless $ref;
    };

    push @cases, map [@$_, +{ map +($_ => 1), split ' ', $_->[1] }], (
        [\1,                         'plain scalar'],
        [[],                         'plain array'],
        [{},                         'plain hash'],
        [sub {},                     'plain code'],
        [\*STDIN,                    'plain glob'],
        [*STDOUT{'IO'},              'io'],
        [qr/^/,                      'regexp'],
        [bless(qr/^/, 'Surprise'),   'randomly-blessed regexp'],
        [\\1,                        'plain ref'],
        [$format,                    'plain format'],

        [do { bless \(my $x = 1) },  'blessed scalar'],
        [bless([]),                  'blessed array'],
        [bless({}),                  'blessed hash'],
        [bless(sub {}),              'blessed code'],
        [$blessed_glob,              'blessed glob'],
        [do { bless \\(my $x = 1) }, 'blessed ref'],
        [$blessed_format,            'blessed format'],
    );

    plan tests => 1 * @cases + 1;  # extra one is for use_ok() above
}

BEGIN {
    use_ok('Ref::Util');

    Ref::Util->import(qw<
        is_arrayref
    >);
}

for my $case (@cases) {
  SKIP:
    {
        my ($value, $desc, $tags) = @$case;
        skip "format references do not exist before Perl 5.8.0", 26
            if NO_FORMAT_REFS && $tags->{format};

        my %got = (
            is_arrayref          => is_arrayref($value),
        );

        my %expected = (
            is_arrayref   => $tags->{array},
        );

        die "Oops, test bug" if keys(%got) != keys(%expected);

        for my $func (sort keys %expected) {
            if ($expected{$func}) {
                ok(  $got{$func}, "$func ($desc)" );
            }
            else {
                ok( !$got{$func}, "!$func ($desc)" );
            }
        }
    }
}
