#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Pod::Usage;
use DBIx::Class::Schema::Loader 'make_schema_at';
use FindBin;
use Path::Class;
use Term::ReadPassword qw( read_password );

#stolen verbatim from lims2_model_dump_schema.pl
#when we have off targets we'll probably want to bring the REL_NAME_MAP hash back in, see above file

my $pg_host      = $ENV{PGHOST};
my $pg_port      = $ENV{PGPORT};
my $pg_database  = $ENV{PGDATABASE};
my $pg_schema    = 'public';
my $pg_user      = $ENV{USER};
my $schema_class = 'WGE::Model::Schema';
my $lib_dir      = dir( $FindBin::Bin )->parent->subdir( 'lib' );
my $overwrite    = 0;
my @components   = qw( InflateColumn::DateTime );

GetOptions(
    'help'            => sub { pod2usage( 1 ) },
    'man'             => sub { pod2usage( 2 ) },
    'host=s'         => \$pg_host,
    'port=s'         => \$pg_port,
    'dbname=s'       => \$pg_database,
    'user=s'         => \$pg_user,
    'schema=s'       => \$pg_schema,
    'schema-class=s' => \$schema_class,
    'lib-dir=s'      => \$lib_dir,
    'component=s@'   => \@components,
    'overwrite!'     => \$overwrite,
) or pod2usage( 2 );

die "Host, port and dbname are required." unless $pg_host and $pg_port and $pg_database;

my $dsn = 'dbi:Pg:dbname=' . $pg_database;

if ( defined $pg_host ) {
    $dsn .= ";host=" . $pg_host;
}

if ( defined $pg_port ) {
    $dsn .= ";port=" . $pg_port;
}

my $pw_prompt = sprintf( 'Enter password for %s%s: ', $pg_user, defined $pg_host ? '@'.$pg_host : '' );
my $pg_password;
while ( not defined $pg_password ) {
    $pg_password = read_password( $pw_prompt );
}

my %opts;

my %make_schema_opts = (
    debug              => 0,
    dump_directory     => $lib_dir->stringify,
    db_schema          => $pg_schema,
    components         => \@components,
    use_moose          => 1,
    #exclude            => qr/fixture_md5/,
    skip_load_external => 1
);

if ( $overwrite ) {
    $make_schema_opts{overwrite_modifications} = 1;
}

make_schema_at(
    $schema_class,
    \%make_schema_opts,
    [ $dsn, $pg_user, $pg_password, {}, \%opts ]
);

1;

__END__

=head1 NAME

dump_schema.pl - use DBIx::Class:Schema::Loader to dump the database to a DBIx::Class model

=head1 SYNOPSIS

dump_schema.pl [options]

    --host            the host where your db is located, defaults to $ENV{PGHOST}
    --port            the port where your db is located, defaults to $ENV{PGPORT}
    --dbname         the db name, defaults to $ENV{PGDATABASE}
    --user            the postgres user to run as, defaults to the user running the script
    --schema          the postgres schema to use, defaults to public
    --schema-class    the class name of your model, defaults to WGE::Model::Schema
    --lib-dir         where to dump the classes, defaults to lib in the parent directory
    --component       DBIx::Class components to import, default is just InflateColumn::DateTime
    --overwrite       if true it will overwrite any changes in the Loader-generated code, defaults to false
    --help            show this dialog

Example usage:

perl ./bin/dump_schema.pl --host localhost --port 5445 --user wge --dbname wge

=head1 DESCRIPTION

Connects to the specified database and runs make_schema_at from the DBIx::Class::Schema::Loader module.
Will prompt for a password.

The code was taken almost exactly from lims2_model_dump_schema.pl

=head AUTHOR

Team87

=cut