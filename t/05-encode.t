#!perl -T
use strict;

use Encode;
use Test::Mojibake;

all_files_encoding_ok(all_files(), $INC{'Encode.pm'});
