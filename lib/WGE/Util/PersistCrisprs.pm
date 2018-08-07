package WGE::Util::PersistCrisprs;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::PersistCrisprs::VERSION = '0.117';
}
## use critic


use Moose::Role;
use MooseX::Types::Path::Class;
with qw( MooseX::SimpleConfig MooseX::Log::Log4perl );

requires qw( execute );

use DBI;

#note: we're expecting the user to have initialised log4perl already

has [ qw( dbi_str species db_user db_pass ) ] => ( 
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has dbh => (
    is         => 'ro',
    isa        => 'DBI::db',
    lazy_build => 1,
    handles    => [ qw( commit rollback ) ],
);

has dry_run => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub _build_dbh {
    my $self = shift;

    # read $self->username and password that we got from configfile
    my $dbh = DBI->connect( 
        $self->dbi_str, 
        $self->db_user, 
        $self->db_pass, 
        { AutoCommit => 0, RaiseError => 1, HandleError => \&handle_error } 
    ) or die "Couldn't connect to db:" . DBI->errstr;

    return $dbh;
}

has species_id => (
    is         => 'ro',
    isa        => 'Int',
    lazy_build => 1
);

sub _build_species_id {
    my $self = shift;
    ## this will be the method from the old file that maps name => id
    #it will need to be changed to use the new species table

    my @species = $self->dbh->selectrow_array( 
        "SELECT numerical_id FROM species where id=?", {}, $self->species 
    );
    
    #make sure we only got one entry back
    if ( @species ) {
        return $species[0];
    }
    else {
        die "Couldn't find '" . $self->species . "' in the species database.";
    }
}

=head2 handle_error

This method will rollback the database and disconnect (then die). 
DBI calls this whenever there's a problem.
Note: not an object method (doesn't need $self)

=cut
sub handle_error {
    my ( $error, $dbh ) = @_;

    #if this is a DBI::dr then it didn't connect properly
    $dbh->rollback;
    $dbh->disconnect;

    die "Aborting, DB query failed:\n $error";
}

1;

__END__

=head1 NAME

WGE::Util::PersistCrisprs - role for different crispr persist types

=head1 DESCRIPTION

A role with all the required methods for a sub class to implement a persist step

=head AUTHOR

Alex Hodgkins

=cut