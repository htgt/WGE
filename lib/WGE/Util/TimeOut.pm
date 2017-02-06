package WGE::Util::TimeOut;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::TimeOut::VERSION = '0.104';
}
## use critic

use strict;
use warnings FATAL => 'all';

# This is an alternative to the Time::Out module which did not work in our case,
# possibly due to the MySQL driver affecting the alarm
# We use a poor man's alarm which kills the process if it runs for too long
# The webapp runs under FCGI which will spawn a new process to replace the dead one
# This is not very graceful but better than the app hanging for long periods of time

use Sub::Exporter -setup => {
    exports => [ qw(
        timeout
    ) ]
};

use Log::Log4perl qw(:easy);

sub timeout{
	my ($time, $code, @args) = @_;

    if($ENV{WGE_NO_TIMEOUT}){
        my @ret = $code->(@args);
        return wantarray ? @ret : $ret[0] ;
    }
	my $pid = $$;
    my $caller = ( caller(1) )[3];

    my $alarm_pid = fork();
    if($alarm_pid == 0){
        # child monitors parent and kills it if it takes too long
        for (1..$time) { sleep 1; kill(0,$pid) || exit }
        ERROR("$caller has timed out - killing process $pid");
        DEBUG("Set environment variable WGE_NO_TIMEOUT=1 to switch off timeout");
        kill 'KILL', $pid;
        exit;
    }

    # Parent runs the code
    my @ret = $code->(@args);

    # Parent kills the child alarm process now that the work is complete
    kill 'KILL', $alarm_pid;

    return wantarray ? @ret : $ret[0] ;
}

1;
