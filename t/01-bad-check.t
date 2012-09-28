#!perl -T
use strict;

use Test::Builder::Tester tests => 1;
use Test::More;

use Test::Mojibake;

BAD: {
    no warnings qw(redefine);
    *Test::Builder::plan = sub {};

    test_out(
        qq(not ok 1 - Mojibake test for t/bad/bad-latin1.pl_),
        qq(not ok 2 - Mojibake test for t/bad/bad-utf8.pl_)
    );

    all_files_encoding_ok(qw(t/_INEXISTENT_ t/bad));

    test_test(
        title   => "couldn't test all_files_encoding_ok(t/bad)",
        skip_err=> 1,
    );
}
