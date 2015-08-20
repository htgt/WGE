#!/usr/bin/perl
 
use strict;

# ppid in /opt/t87/local/run/wge2/fastcgi.pid
# try 600,000KB as limit
my ($ppid, $kbytes, $debug) = @ARGV;
 
die "Usage: kidreaper PPID ram_limit_in_kb\n" unless $ppid && $kbytes;
 
my $kids;
 
if (open($kids, "/bin/ps -o pid=,vsz= --ppid $ppid|")) {
   my @goners;
 
   while (<$kids>) {
      chomp;
      my ($pid, $mem) = split;
 
      if ($mem >= $kbytes) {
         push @goners, $pid;
      }
   }
 
   close($kids);
 
   if (@goners) {
      # kill them slowly, so that all connection serving
      # children don't suddenly die at once.
 
      foreach my $victim (@goners) {
         print "Killing $victim\n" if $debug;
         kill 'HUP', $victim;
         sleep 10;
      }
   }
}
else {
   die "Can't get process list: $!\n";
}