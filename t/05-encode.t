#!perl -T
use strict;

use Encode;
use Test::Mojibake;

all_files_encoding_ok($INC{'Encode.pm'});
