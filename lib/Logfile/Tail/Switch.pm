package Logfile::Tail::Switch;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use File::Tail;

sub new {
    my ($class, $glob) = @_;

    my $self = {
        glob => $glob,
    };

    bless $self, $class;
}

sub _switch_cur {
    my ($self, $filename) = @_;

    $self->{_cur} = File::Tail->new($filename);
}

sub getline {
    my $self = shift;

    my $now = time();

  CHECK_NEWER_FILES:
    {
        last unless !$self->{_last_check_time} || $self->{_last_check_time} < $now - 5;
        my @files = sort glob($self->{glob});
        last unless @files;
        if (defined $self->{_cur}) {
            for (@files) {
                # there is a newer file than the current one, add to the pending
                # list of files to be read after the current one
                $self->{_pending}{$_} = 1
                    if $_ gt $self->{_cur};
            }
        } else {
            # at the beginning, pick the newest file in the pattern and tail it
            $self->_switch_cur($glob, $files[-1], 1);
            $self->{_pending}{$glob} = {};
        }
    }

  GLOB:
    for my $glob (keys %{ $self->{_cur_fh} }) {
      READ:
        my $fh = $self->{_cur_fh}{$glob};
        my $line = $fh->getline;
        if (defined $line) {
            return $line;
        } else {
            #say "D:got undef";
            $self->{_cur_eof}{$glob} = 1 if $fh->eof;
            if ($self->{_cur_eof}{$glob}) {
                #say "D:is eof";
                # we are at the end of the file ...
                my @pending = sort keys %{ $self->{_pending}{$glob} };
                if (@pending) {
                    #say "D:has pending file";
                    # if there is another file pending, switch to that file
                    $self->_switch_cur($glob, $pending[0]);
                    delete $self->{_pending}{$glob}{$pending[0]};
                    goto READ;
                } else {
                    #say "D:no pending file";
                    # there is no other file, keep at the current file
                    next GLOB;
                }
            } else {
                #say "D:not eof";
            }
        }
    }
    undef;
}

1;
#ABSTRACT: Tail a file, but switch when another file with newer name appears

=for Pod::Coverage ^(DESTROY)$

=head1 SYNOPSIS

 use Logfile::Tail::Switch;
 use Time::HiRes 'sleep'; # for subsecond sleep

 my $tail = Logfile::Tail::Switch->new(
     glob => "/s/example.com/syslog/http_access.*.log",
 );

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

=head2 Logfile::Tail::Switch->new(%args) => obj

Constructor. Arguments:

=over

=item * glob => str

=back

=head2 $tail->getline() => str

Will return the next line or empty string if no new line is available.


=head1 SEE ALSO

L<File::Tail>, L<File::Tail::Dir>, L<IO::Tail>

Spanel, L<http://spanel.info>.

=cut
