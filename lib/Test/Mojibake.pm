#!/usr/bin/perl
package Test::Mojibake;
# ABSTRACT: check your source for encoding misbehavior.

=encoding utf8

=head1 SYNOPSIS

C<Test::Mojibake> lets you check for inconsistencies in source/documentation encoding, and report its results in standard C<Test::Simple> fashion.

    use Test::Mojibake tests => $num_tests;
    file_encoding_ok($file, 'Valid encoding');

Module authors can include the following in a F<t/mojibake.t> file and have C<Test::Mojibake> automatically find and check all source files in a module distribution:

    #!perl -T
    use strict;

    BEGIN {
        unless ($ENV{RELEASE_TESTING}) {
            require Test::More;
            Test::More::plan(skip_all => 'these tests are for release candidate testing');
        }
    }

    use Test::More;

    eval { use Test::Mojibake; };
    plan skip_all => 'Test::Mojibake required for source encoding testing' if $@;

    all_files_encoding_ok();

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
        no strict 'refs';   ## no critic
        *{$caller."::".$func} = \&$func;
    }

    $Test->exported_to($caller);
    $Test->plan(@_);
}

=func file_encoding_ok( FILENAME[, TESTNAME ] )

...

=cut

sub file_encoding_ok {
    my $file = shift;
    my $name = @_ ? shift : "Mojibake test for $file";

    unless (-f $file) {
        $Test->ok(0, $name);
        $Test->diag("$file does not exist");
        return;
    }

    my $fh;
    unless (open($fh, '<:raw', $file)) {
        $Test->ok(0, $name);
        $Test->diag("Can't open $file: $!");
        return;
    }

    my $use_utf8    = 0;
    my $pod         = 0;
    my $pod_utf8    = 0;
    my $n           = 1;
    while (my $line = <$fh>) {
        if (($n == 1) && $line =~ /^\x{EF}\x{BB}\x{BF}/) {
            $Test->ok(0, $name);
            $Test->diag("UTF-8 BOM (Byte Order Mark) found in $file");
            return;
        } elsif ($line =~ /^=+cut\s*$/) {
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
            $line =~ s/^\s*#.*$//s;     # disclaimers placed in headers frequently contain UTF-8 *before* it's usage is declared.
            foreach (split m{;}, $line) {
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

                if (($use_utf8 == 0) && $utf8) {
                    $Test->ok(0, $name);
                    $Test->diag("UTF-8 unexpected in $file, line $n (source)");
                    return;
                } elsif (($use_utf8 == 1) && $latin1) {
                    $Test->ok(0, $name);
                    $Test->diag("Non-UTF-8 unexpected in $file, line $n (source)");
                    return;
                }
            }
        } else {
            # POD
            my @type = qw(0 0 0);
            ++$type[_detect_utf8(\$line)];
            my ($latin1, $ascii, $utf8) = @type;

            if (($pod_utf8 == 0) && $utf8) {
                $Test->ok(0, $name);
                $Test->diag("UTF-8 unexpected in $file, line $n (POD)");
                return;
            } elsif (($pod_utf8 == 1) && $latin1) {
                $Test->ok(0, $name);
                $Test->diag("Non-UTF-8 unexpected in $file, line $n (POD)");
                return;
            }
        }
    } continue {
        ++$n;
    }
    close $fh;

    $Test->ok(1, $name);
    return 1;
}

=func all_files_encoding_ok( [@entries] )

Validates codification of all the files under C<@entries>. It runs L<all_files()> on directories and assumes everything else to be a file to be tested. It calls the C<plan()> function for you (one test for each file), so you can't have already called C<plan>.

If C<@entries> is empty or not passed, the function finds all source/documentation files in files in the F<blib> directory if it exists, or the F<lib> directory if not. A source/documentation file is one that ends with F<.pod>, F<.pl> and F<.pm>, or any file where
the first line looks like a shebang line.

=cut

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

=func all_files( [@dirs] )

Returns a list of all the Perl files in I<@dirs> and in directories below. If no directories are passed, it defaults to F<blib> if F<blib> exists, or else F<lib> if not. Skips any files in CVS, .svn, .git and similar directories. See C<%Test::Mojibake::ignore_dirs> for a list of them.

A Perl file is:

=for :list
* Any file that ends in F<.PL>, F<.pl>, F<.pm>, F<.pod>, or F<.t>.
* Any file that has a first line with a shebang and "perl" on it.
* Any file that ends in F<.bat> and has a first line with "--*-Perl-*--" on it.

The order of the files returned is machine-dependent.  If you want them
sorted, you'll have to sort them yourself.

=cut

sub all_files {
    my @queue = @_ ? @_ : _starting_points();
    my @mod = ();

    while (@queue) {
        my $file = shift @queue;
        if (-d $file) {
            opendir my $dh, $file or next;
            my @newfiles = readdir $dh;
            closedir $dh;

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

=func _detect_utf8( \$string )

Detects presence of UTF-8 encoded characters in a referenced octet stream.

Return codes:

=for :list
* 0 - 8-bit characters detected, does not validate as UTF-8;
* 1 - only 7-bit characters;
* 2 - 8-bit characters detected, validates as UTF-8.

Original code, in PHP: L<http://www.php.net/manual/en/function.utf8-encode.php#85293>

=cut

sub _detect_utf8 {
    use bytes;

    my $str     = shift;
    my $d       = 0;
    my $c       = 0;
    my $b       = 0;
    my $bits    = 0;
    my $len     = length ${$str};

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

=head1 SEE ALSO

=for :list
* L<Test::Perl::Critic>
* L<Test::Pod>
* L<Test::Pod::Coverage>
* L<Test::Kwalitee>

=head1 ACKNOWLEDGEMENTS

This module is based on L<Test::Pod>.

Thanks to
Andy Lester,
David Wheeler,
Paul Miller
and
Peter Edwards
for contributions and to C<brian d foy> for the original code.

=cut

1;
