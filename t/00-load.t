#!perl -T
use strict;

use Test::More tests => 2;

BEGIN {
    use_ok('Test::Builder');
    use_ok('Test::Mojibake');
}

diag("Testing Test::Mojibake $Test::Mojibake::VERSION, Perl $], $^X");
diag("Using Test::Builder $Test::Builder::VERSION");
