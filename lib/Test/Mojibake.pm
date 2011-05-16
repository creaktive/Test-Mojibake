#!/usr/bin/perl
package Test::Mojibake;
# ABSTRACT: check your source for encoding misbehavior.

=encoding utf8

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use utf8;
use warnings 'all';

our $VERSION = '0.1';

use 5.008;
use File::Spec;
use Test::Builder;

our %ignore_dirs = (
    '.bzr'  => 'Bazaar',
    '.git'  => 'Git',
    '.hg'   => 'Mercurial',
    '.pc'   => 'quilt',
    '.svn'  => 'Subversion',
    CVS     => 'CVS',
    RCS     => 'RCS',
    SCCS    => 'SCCS',
    _darcs  => 'darcs',
    _sgbak  => 'Vault/Fortress',
);

my $Test = new Test::Builder;

sub import {
    my $self = shift;
    my $caller = caller;

    for my $func (qw(file_encoding_ok all_files all_files_encoding_ok)) {
        no strict 'refs';
        *{$caller."::".$func} = \&$func;
    }

    $Test->exported_to($caller);
    $Test->plan(@_);
}

sub file_encoding_ok {
    my $file = shift;
    my $name = @_ ? shift : "Mojibake test for $file";

    unless (-f $file) {
        $Test->ok(0, $name);
        $Test->diag("$file does not exist");
        return;
    }

    local *FILE;
    unless (open(FILE, '<:raw', $file)) {
        $Test->ok(0, $name);
        $Test->diag("Can't open $file: $!");
        return;
    }

    my $use_utf8    = 0;
    my $pod         = 0;
    my $pod_utf8    = 0;
    my $n           = 1;
    while (my $line = <FILE>) {
        if (($n == 1) && $line =~ /^\x{EF}\x{BB}\x{BF}/) {
            $Test->ok(0, $name);
            $Test->diag("UTF-8 BOM (Byte Order Mark) found in $file");
            return;
        } elsif ($line =~ /^=cut\b/) {
            $pod = 0;
        } elsif ($line =~ /^=+encoding\s+([\w\-]+)/) {
            my $pod_encoding = lc $1;
            $pod_encoding =~ y/-//d;
            $pod_utf8 = ($pod_encoding eq 'utf8') ? 1 : 0;
            $pod = 1;
        } elsif ($line =~ /^=+\w+/) {
            $pod = 1;
        } elsif ($pod == 0) {
            # source
            foreach (split m{;}, $line) {
                s/#.*$//s;
                s/^\s+//s;
                s/\s+$//s;

                my @type = qw(0 0 0);
                ++$type[_detect_utf8(\$_)];
                my ($latin1, $ascii, $utf8) = @type;

                if (/^use\s+utf8$/) {
                    $use_utf8 = 1;
                } elsif (/^use\s+common::sense$/) {
                    $use_utf8 = 1;
                } elsif (/^no\s+utf8$/) {
                    $use_utf8 = 0;
                }

                if (($use_utf8 == 0) && ($utf8)) {
                    $Test->ok(0, $name);
                    $Test->diag("UTF-8 unexpected in $file, line $n (source)");
                    return;
                } elsif (($use_utf8 == 1) && ($latin1)) {
                    $Test->ok(0, $name);
                    $Test->diag("Latin-1 unexpected in $file, line $n (source)");
                    return;
                }
            }
        } else {
            # POD
            my @type = qw(0 0 0);
            ++$type[_detect_utf8(\$line)];
            my ($latin1, $ascii, $utf8) = @type;

            if (($pod_utf8 == 0) && ($utf8)) {
                $Test->ok(0, $name);
                $Test->diag("UTF-8 unexpected in $file, line $n (POD)");
                return;
            } elsif (($pod_utf8 == 1) && ($latin1)) {
                $Test->ok(0, $name);
                $Test->diag("Latin-1 unexpected in $file, line $n (POD)");
                return;
            }
        }
    } continue {
        ++$n;
    }
    close FILE;

    $Test->ok(1, $name);
    return 1;
}

sub all_files_encoding_ok {
    my @args = @_ ? @_ : _starting_points();
    my @files = map { -d $_ ? all_files($_) : $_ } @args;

    $Test->plan(tests => scalar @files);

    my $ok = 1;
    foreach my $file (@files) {
        file_encoding_ok($file) or undef $ok;
    }
    return $ok;
}

sub all_files {
    my @queue = @_ ? @_ : _starting_points();
    my @mod = ();

    while (@queue) {
        my $file = shift @queue;
        if (-d $file) {
            local *DH;
            opendir DH, $file or next;
            my @newfiles = readdir DH;
            closedir DH;

            @newfiles = File::Spec->no_upwards(@newfiles);
            @newfiles = grep { not exists $ignore_dirs{$_} } @newfiles;

            foreach my $newfile (@newfiles) {
                my $filename = File::Spec->catfile($file, $newfile);
                if (-f $filename) {
                    push @queue, $filename;
                }else {
                    push @queue, File::Spec->catdir($file, $newfile);
                }
            }
        }
        if (-f $file) {
            push @mod, $file if _is_perl($file);
        }
    }
    return @mod;
}

sub _starting_points {
    return 'blib' if -e 'blib';
    return 'lib';
}

sub _is_perl {
    my $file = shift;

    return 1 if $file =~ /\.PL$/;
    return 1 if $file =~ /\.p(?:l|m|od)$/;
    return 1 if $file =~ /\.t$/;

    open my $fh, '<', $file or return;
    my $first = <$fh>;
    close $fh;

    return 1 if defined $first && ($first =~ /(?:^#!.*perl)|--\*-Perl-\*--/);

    return;
}

sub _detect_utf8 {
    use bytes;

    my $str = shift;
    my $d = 0;
    my $c = 0;
    my $b = 0;
    my $bits = 0;
    my $len = length ${$str};

    for (my $i = 0; $i < $len; $i++) {
        $c = ord(substr(${$str}, $i, 1));
        if ($c >= 128) {
            $d++;

            if ($c >= 254) {
                return 0;
            } elsif ($c >= 252) {
                $bits = 6;
            } elsif ($c >= 248) {
                $bits = 5;
            } elsif ($c >= 240) {
                $bits = 4;
            } elsif ($c >= 224) {
                $bits = 3;
            } elsif ($c >= 192) {
                $bits = 2;
            } else {
                return 0;
            }

            if (($i + $bits) > $len) {
                return 0;
            }

            while ($bits > 1) {
                $i++;
                $b = ord(substr(${$str}, $i, 1));
                if (($b < 128) || ($b > 191)) {
                    return 0;
                }
                $bits--;
            }
        }
    }

    return $d ? 2 : 1;
}

1;
