#!perl

BEGIN {
    unless ($ENV{RELEASE_TESTING}) {
        require Test::More;
        Test::More::plan(skip_all => 'these tests are for release candidate testing');
    }
}

use strict;
use warnings;
use Test::More; # needed to provide plan.

eval {
    require Test::Kwalitee;
    Test::Kwalitee->import(tests =>[qw(-no_pod_errors)]);
};

plan skip_all => "Test::Kwalitee required for testing kwalitee" if $@;
