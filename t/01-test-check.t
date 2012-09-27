#!perl -T
use strict;

use Test::Mojibake;
all_files_encoding_ok(qw(t/_INEXISTENT_ t/good));
