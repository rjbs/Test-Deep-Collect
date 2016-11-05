use strict;
use warnings;

use Test::Tester;

use Test::More;
use Test::Deep;
use Test::Deep::Collect;

my @same = qw( badger badger badger badger );
my @uniq = qw( badger mushroom snake );

subtest "unique are unique" => sub {
  my $col = collector;
  check_test(
    sub { cmp_deeply(\@uniq, array_each( $col->uniq("thinger"))); },
    {
      ok => 1,
    },
    "unique are unique"
  );

  is_deeply([ $col->values('thinger') ], \@uniq, "values collected");
  is_deeply([ $col->unique_values('thinger') ], \@uniq, "values uniqued");
};

subtest "same are not unique" => sub {
  my $col = collector;
  check_test(
    sub { cmp_deeply(\@same, array_each( $col->uniq("thinger") )); },
    {
      ok => 0,
      diag => <<'END_DIAG'
$data->[1] repeats previously seen value for thinger
   got : 'badger'
expect : anything other than: 'badger'
END_DIAG
    },
    "same are not unique"
  );

  # array_each stops running after its first failure, so we won't see every
  # same value, only up to the first repeat. -- rjbs, 2016-11-04
  is_deeply([ $col->values('thinger') ], [@same[0,1]], "values collected");
  is_deeply([ $col->unique_values('thinger') ], [ $same[0] ], "values uniqued");
};

subtest "same are same" => sub {
  my $col = collector;
  check_test(
    sub { cmp_deeply(\@same, array_each( $col->same("thinger"))); },
    {
      ok => 1,
    },
    "unique are unique"
  );

  is_deeply([ $col->values('thinger') ], \@same, "values collected");
  is_deeply([ $col->unique_values('thinger') ], [ $same[0] ], "values uniqued");
};

subtest "unique are not same" => sub {
  my $col = collector;
  check_test(
    sub { cmp_deeply(\@uniq, array_each( $col->same("thinger") )); },
    {
      ok => 0,
      diag => <<'END_DIAG'
$data->[1] differs from initial value for thinger
   got : 'mushroom'
expect : 'badger'
END_DIAG
    },
    "same are not unique"
  );

  # array_each stops running after its first failure, so we won't see every
  # same value, only up to the first repeat. -- rjbs, 2016-11-04
  is_deeply([ $col->values('thinger') ], [@uniq[0,1]], "values collected");
  is_deeply([ $col->unique_values('thinger') ], [@uniq[0,1]], "values uniqued");
};

subtest "undef is allowed and unique from ''" => sub {
  my @input = ('abc', '', 'def', undef, 'ghi');

  my $col = collector;
  check_test(
    sub {
      cmp_deeply(
        \@input,
        array_each( $col->uniq("thinger") )
      );
    },
    {
      ok => 1,
    },
    "same are not unique"
  );

  # array_each stops running after its first failure, so we won't see every
  # same value, only up to the first repeat. -- rjbs, 2016-11-04
  is_deeply([ $col->values('thinger') ], \@input, "values collected");
  is_deeply([ $col->unique_values('thinger') ], \@input, "values uniqued");
};

subtest "chaining and saving" => sub {
  my $col = collector;
  my $have = {
    username => 'rrenfield',
    manager  => 'vtepes',
  };

  check_test(
    sub {
      cmp_deeply(
        $have,
        {
          username => $col->unique('ids')->save('username'),
          manager  => $col->unique('ids')->save('manager'),
        },
      );
    },
    {
      ok => 1,
    },
    "assert uniqueness and save data"
  );

  cmp_deeply(
    [ $col->values('ids') ],
    bag(qw( rrenfield vtepes )),
    "all ids saved",
  );

  is($col->single_value("username"), 'rrenfield', "saved username");
  is($col->single_value("manager"),  'vtepes',    "saved manager");
};

done_testing;
