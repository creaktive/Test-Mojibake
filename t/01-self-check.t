#!perl -T
use strict;

use Test::More tests => 2;

BEGIN {
    use_ok('Test::Mojibake');
}

my $self = $INC{'Test/Mojibake.pm'};
file_encoding_ok($self, "My own encoding is OK");
