#!perl -T
use strict;

use Test::More tests => 5;

BEGIN {
    use_ok('Test::Mojibake');
}

for (qw(ascii latin1 utf8 mojibake)) {
    my $file = 't/good/' . $_ . '.pod';
    file_encoding_ok($file, "$file encoding is OK");
}
