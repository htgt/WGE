#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use FCGI::Engine::Manager;
use Pod::Usage;
use Getopt::Long;

GetOptions(
    'help'     => sub { pod2usage( -verbose => 1 ) },
    'man'      => sub { pod2usage( -verbose => 2 ) },
    'config=s' => \my $config
) and @ARGV == 2 or pod2usage(2);

my ($command, $server_name) = @ARGV;

my $m = FCGI::Engine::Manager->new( conf => $config );

if ( $command eq 'start' ) {
    $m->start( $server_name );
}
elsif ( $command eq 'stop' ) {
    $m->stop( $server_name );
}
elsif ( $command eq 'restart' ) {
    $m->restart( $server_name );
}
elsif ( $command eq 'graceful' or $command eq 'reload' ) {
    $m->graceful( $server_name );
}
elsif ( $command eq 'status' ) {
    print $m->status( $server_name );
}
else {
    pod2usage( "unrecognized action: $command" );
}

__END__

=pod

=head1 NAME

fcgi-manager.pl

=head1 SYNOPSIS

  fcgi-manager.pl --config=PATH start|stop|restart|reload|graceful|status SERVER_NAME

=head1 DESCRIPTION

Utility script to start/stop/restart/reload or query the status of a FastCGI process.

=head1 SEE ALSO

L<FCGI::Engine::Manager>

=head1 AUTHOR

Ray Miller, E<lt>rm7@sanger.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Genome Research Ltd

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
