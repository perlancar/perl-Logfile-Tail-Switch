package Logfile::Tail::Switch;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Time::HiRes 'time';

sub new {
    my ($class, $glob, $opts) = @_;

    defined($glob) or die "Please specify glob";
    $opts //= {};

    $opts->{check_freq} //= 5;

    my $self = {
        glob => $glob,
        opts => $opts,
        _cur_file => undef,
        _cur_fh   => undef,
        _pending  => {},
    };

    bless $self, $class;
}

sub _switch {
    my ($self, $filename, $seek_end) = @_;

    #say "D: opening $filename";
    $self->{_cur_file} = $filename;
    open my $fh, "<", $filename or die "Can't open $filename: $!";
    seek $fh, 0, 2 if $seek_end;
    $self->{_cur_fh} = $fh;
}

sub _getline {
    my $self = shift;

    my $fh = $self->{_cur_fh};
    my $size = -s $fh;
    my $pos = tell $fh;
    if ($pos == $size) {
        # we are still at the end of file, return empty string
        return '';
    } elsif ($pos > $size) {
        # file reduced in size, it probably means it has been rotated, start
        # from the beginning
        seek $fh, 0, 0;
    } else {
        # there are new content to read after our position
    }
    return(<$fh> // '');
}

sub getline {
    my $self = shift;

    my $now = time();

  CHECK_NEWER_FILES:
    {
        last if $self->{_last_check_time} &&
            $self->{_last_check_time} >= $now - $self->{opts}{check_freq};
        #say "D: checking for newer file";
        my @files = sort glob($self->{glob});
        #say "D: files matching glob: ".join(", ", @files);
        $self->{_last_check_time} = $now;
        unless (@files) {
            warn "No files matched '$self->{glob}'";
            last;
        }
        if (defined $self->{_cur_fh}) {
            for (@files) {
                # there is a newer file than the current one, add to the pending
                # list of files to be read after the current one
                #say "D: there is a newer file: $_";
                $self->{_pending}{$_} = 1
                    if $_ gt $self->{_cur_file};
            }
        } else {
            # this is our first time, pick the newest file in the pattern and
            # tail it.
            $self->_switch($files[-1], 1);
        }
    }

    # we don't have any matching files
    return '' unless $self->{_cur_fh};

    my $line = $self->_getline;
    if (!length($line) && keys %{$self->{_pending}}) {
        # switch to a newer named file
        my @files = sort keys %{$self->{_pending}};
        $self->_switch($files[0]);
        delete $self->{_pending}{$files[0]};
        $line = $self->_getline;
    }
    $line;
}

1;
#ABSTRACT: Tail a file, but switch when another file with newer name appears

=for Pod::Coverage ^(DESTROY)$

=head1 SYNOPSIS

 use Logfile::Tail::Switch;
 use Time::HiRes 'sleep'; # for subsecond sleep

 my $tail = Logfile::Tail::Switch->new("/s/example.com/syslog/http_access.*.log");

 # tail
 while (1) {
     my $line = $tail->getline;
     if (length $line) {
         print $line;
     } else {
        sleep 0.1;
     }
 }


=head1 DESCRIPTION

This class can be used to tail a file, but switch when a file of a newer name
appears. For example, on an Spanel server, the webserver is configured to write
to daily log files:

 /s/<SITE-NAME>/syslog/http_access.<YYYY>-<MM>-<DD>.log
 /s/<SITE-NAME>/syslog/https_access.<YYYY>-<MM>-<DD>.log

So, when tailing you will need to switch to a new log file if you cross day
boundary.

When using this class, you specify a glob pattern of files, e.g.
C</s/example.com/syslog/http_access.*.log>. Then you call the C<getline> method.

This class will first select the newest file (via asciibetical sorting) from the
glob pattern and tail it. Then, periodically (by default at most every 5
seconds) the glob pattern will be checked again. If there is one or more newer
files, they will be read in full and then tail-ed, until an even newer file
comes along. For example, this is the list of files in C</s/example.com/syslog>
at time I<t1>:

 http_access.2017-06-05.log.gz
 http_access.2017-06-06.log
 http_access.2017-06-07.log

C<http_access.2017-06-07.log> will first be tail-ed. When
C<http_access.2017-06-08.log> appears at time I<t2>, this file will be read from
start to finish then tail'ed. When C<http_access.2017-06-09.log> appears the
next day, that file will be read then tail'ed. And so on.


=head1 METHODS

=head2 Logfile::Tail::Switch->new($glob [, \%opts ]) => obj

Constructor.

Known options:

=over

=item * check_freq => posint (default: 5)

=back

=head2 $tail->getline() => str

Will return the next line or empty string if no new line is available.


=head1 SEE ALSO

L<File::Tail>, L<File::Tail::Dir>, L<IO::Tail>

L<Tie::Handle::TailSwitch>

L<tailswitch> from L<App::tailswitch>

Spanel, L<http://spanel.info>.

=cut
