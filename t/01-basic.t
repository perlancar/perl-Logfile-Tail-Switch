#!perl

use 5.010001;
use strict;
use warnings;
use Test::More 0.98;

use File::Temp qw(tempdir);
use Logfile::Tail::Timestamp;
use Time::HiRes 'sleep';

my $tempdir = tempdir();
diag "tempdir: $tempdir";

sub _append {
    my ($filename, $str) = @_;
    open my $fh, ">>", $filename or die;
    #$fh->autoflush(1);
    print $fh $str;
    close $fh;
}

subtest "single glob" => sub {
    my $dir = "$tempdir/1";
    mkdir $dir, 0755 or die;
    chdir $dir or die;
    _append("log-a", "one-a\n");
    _append("log-b", "one-b\n");
    my $tail = Logfile::Tail::Timestamp->new(
        globs => ["log-*"],
    );
    is_deeply($tail->getline, undef, "initial");
    _append("log-a", "two-a\n");
    is_deeply($tail->getline, undef, "line added to log-a has no effect");
    _append("log-b", "two-b\nthree-b\n");
    is_deeply($tail->getline, "two-b\n", "line added to log-b is seen (1)");
    is_deeply($tail->getline, "three-b\n", "line added to log-b is seen (2)");
};

subtest "two globs" => sub {
    my $dir = "$tempdir/2";
    mkdir $dir, 0755 or die;
    chdir $dir or die;

    ok 1;
};

done_testing;
