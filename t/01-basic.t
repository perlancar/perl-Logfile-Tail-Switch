#!perl

use 5.010001;
use strict;
use warnings;
use Test::More 0.98;

use File::Temp qw(tempdir);
use Logfile::Tail::Switch;
use Time::HiRes 'sleep';

my $tempdir = tempdir();
note "tempdir: $tempdir";

sub _append {
    my ($filename, $str) = @_;
    open my $fh, ">>", $filename or die;
    print $fh $str;
    close $fh;
}

subtest "no matching files" => sub {
    my $dir = "$tempdir/nomatch";
    mkdir $dir, 0755 or die;
    chdir $dir or die;

    my $tail = Logfile::Tail::Switch->new("*");
    is($tail->getline, '');
};

subtest "basic" => sub {
    my $dir = "$tempdir/basic";
    mkdir $dir, 0755 or die;
    chdir $dir or die;

    _append("log-a", "one-a\n");
    _append("log-b", "one-b\n");
    my $tail = Logfile::Tail::Switch->new("log-*", {check_freq=>0.1});
    is($tail->getline, '', "initial");
    _append("log-a", "two-a\n");
    is($tail->getline, '', "line added to log-a has no effect");
    _append("log-b", "two-b\nthree-b\n");
    is($tail->getline, "two-b\n", "line added to log-b is seen (1)");
    is($tail->getline, "three-b\n", "line added to log-b is seen (2)");
    is($tail->getline, "", "no more lines");

    _append("log-c", "one-c\ntwo-c\n");
    _append("log-d", "one-d\ntwo-d\n");
    is($tail->getline, "", "no more lines yet");
    sleep 0.11;
    is($tail->getline, "one-c\n", "line from log-c is seen (1)");
    is($tail->getline, "two-c\n", "line from log-c is seen (1)");
    is($tail->getline, "one-d\n", "line from log-d is seen (2)");
    is($tail->getline, "two-d\n", "line from log-d is seen (2)");
    is($tail->getline, "", "no more lines (2)");

    _append("log-b", "four-b\n");
    is($tail->getline, '', "line added to log-b now has no effect");
    _append("log-c", "three-c\n");
    is($tail->getline, '', "line added to log-c has no effect");
    _append("log-d", "three-d\n");
    is($tail->getline, "three-d\n", "line from log-d is seen");
};

# XXX truncating a log file

done_testing;
