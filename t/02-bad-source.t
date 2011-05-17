#!perl -T
use strict;

use Test::Builder::Tester tests => 3;
use Test::More;

BEGIN {
    use_ok('Test::Mojibake');
}

BAD: {
    my ($name, $file);

    $name = 'Latin-1 with "use utf8"!';
    $file = 't/bad-latin1.pl';
    test_out("not ok 1 - $name");
    file_encoding_ok($file, $name);
    test_fail(-1);
    test_diag("Non-UTF-8 unexpected in $file, line 4 (source)");
    test_test("$name is bad");

    $name = 'UTF-8 with no "use utf8"!';
    $file = 't/bad-utf8.pl';
    test_out("not ok 1 - $name");
    file_encoding_ok($file, $name);
    test_fail(-1);
    test_diag("UTF-8 unexpected in $file, line 3 (source)");
    test_test("$name is bad");
}
