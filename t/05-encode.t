#!perl -T
use strict;

use encoding 'latin1';
use Encode;
use Test::Mojibake;

all_files_encoding_ok(values %INC);
