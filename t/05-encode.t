#!perl -T
use strict;

use Encode;
use Test::Mojibake;

my $encode = $INC{'Encode.pm'};
$encode =~ s{\.pm$}{/};

all_files_encoding_ok($encode);
