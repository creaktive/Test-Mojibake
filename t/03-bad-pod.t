#!perl -T
use strict;

use Test::Builder::Tester tests => 3;
use Test::More;

BEGIN {
    use_ok('Test::Mojibake');
}

BAD: {
    my ($name, $file);

    $name = 'Latin-1 with "=encoding utf8"!';
    $file = 't/bad/bad-latin1.pod_';
    test_out("not ok 1 - $name");
    file_encoding_ok($file, $name);
    test_fail(-1);
    test_diag("UTF-8 unexpected in $file, line 5 (POD)");
    test_test("$name is bad");

    $name = 'UTF-8 with no "=encoding utf8"!';
    $file = 't/bad/bad-utf8.pod_';
    test_out("not ok 1 - $name");
    file_encoding_ok($file, $name);
    test_fail(-1);
    test_diag("Non-UTF-8 unexpected in $file, line 7 (POD)");
    test_test("$name is bad");
}
