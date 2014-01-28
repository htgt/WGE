package WGE::Util::PersistCrisprs;

use Moose;
use MooseX::Types::Path::Class;
with qw( MooseX::SimpleConfig MooseX::Log::Log4perl );

use DBI;
use Data::Dumper;
use YAML::Any qw( LoadFile );
use Try::Tiny;

#note: we're expecting the user to have initialised log4perl already
has '+configfile' => (
    default => $ENV{WGE_REST_CLIENT_CONFIG} || 
               '/nfs/team87/farm3_lims2_vms/conf/wge-live-rest-client.conf',
);

has [ qw( dbi_str species username password ) ] => ( 
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has [ qw( bed_file crispr_yaml_file ) ] => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
    coerce   => 1,
);

has max_offs => (
    is      => 'rw',
    isa     => 'Int',
    default => '5000',
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
        $self->username, 
        $self->password, 
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

=head2 execute

Run all the usual steps in order and commit it. This is 
just the most common usage of this module

=cut
sub execute {
    my $self = shift;

    #these will die if they fail
    $self->create_temp_tables;
    $self->update_off_targets;
    $self->update_summaries;

    #if we get here without dying everything was successful
    if ( $self->dry_run ) {
        $self->rollback;
    }
    else {
        $self->commit;
    }

    return 1;
}

=head2 create_temp_tables

Parse the specified bed and crispr files, and insert all fetched
data into two temporary tables, bed and summ.

=cut
sub create_temp_tables {
    my $self = shift;

    #get all data from the bed file in the format we want
    my ( $ots_tsv, $summary_tsv );
    my $crisprs = $self->_process_bed;
    while ( my ( $id, $ots ) = each %{ $crisprs } ) {
        my $total_offs = scalar( @{ $ots->{all} } );
        if ( $total_offs > $self->max_offs ) {
            $self->log->warn( "$id has " . $total_offs . " off targets, skipping." ); 
        }
        else {
            $ots_tsv .= join( "\n", @{ $ots->{all} } ) . "\n";
        }

        #separate tsv for summary data
        $summary_tsv .= $id . "\t" . $ots->{summary} . "\n";

        #try and save SOME memory
        delete $crisprs->{ $id }; #apparently this is fine (from perl 5.8 onwards) 
    }

    $self->log->info( "Creating temp tables" );

    #make temp table and shove all the data in
    $self->dbh->do( "CREATE TEMP TABLE bed (chr_name TEXT, chr_start INTEGER, c_id INTEGER) ON COMMIT DROP" );
    $self->dbh->do( "COPY bed (chr_name, chr_start, c_id) FROM STDIN" );
    $self->dbh->pg_putcopydata( $ots_tsv );
    $self->dbh->pg_putcopyend();
    $self->dbh->do( "CREATE INDEX idx_id ON bed (c_id)" );

    $self->dbh->do( "CREATE TEMP TABLE summ (c_id INTEGER, summary TEXT) ON COMMIT DROP" );
    $self->dbh->do( "COPY summ (c_id, summary) FROM STDIN" );
    $self->dbh->pg_putcopydata( $summary_tsv );
    $self->dbh->pg_putcopyend();

    $self->log->info( "Finished temp tables" );

    return;
}

=head2 _process_bed

Return a hash of tsv data grouped by crispr (gotten from the bed file), 
and the summaries from the crispr yaml file

=cut
sub _process_bed {
    my ( $self ) = shift;

    my %crisprs;
    my $count = 0;
    
    my $crispr_yaml = LoadFile( $self->crispr_yaml_file->stringify );

    $self->log->info( 'Processing bed file' );
    my $fh = $self->bed_file->openr;

    #iterate over the bed file, grouping the crisprs by exon id.
    #we store the off target summary as well as each individual crispr loci
    while ( <$fh> ) {
        my @cols = split /\s+/, $_;

        #split up seq and id
        my ( $name, $seq ) = split /-/, $cols[3];
        my ( $exon_id, $db_id, $type ) = $name =~ /([A-Z0-9]+)_(\d+)([AB])$/;

        die "Can't find '$exon_id' in crispr yaml!"
            unless defined $exon_id and exists $crispr_yaml->{ $exon_id };

        die "Couldn't extract db id from $name!" 
            unless defined $db_id and exists $crispr_yaml->{ $exon_id }{ $db_id };

        $cols[0] =~ s/^Chr//;
        
        #first column is chromosome, second is start
        #yes we duplicate the db_id but we need it all in a string and this
        #makes processing easier later
        push @{ $crisprs{$db_id}->{all} }, join "\t", $cols[0], $cols[1], $db_id;

        $crisprs{$db_id}->{summary} = $crispr_yaml->{$exon_id}{$db_id}{off_target_summary};

        die "Summary is empty for $db_id$type" unless defined $crisprs{$db_id}->{summary};

        $count++;

        #last if $count > 108103;
    }

    die "No data found in bed file." unless %crisprs;

    $self->log->info( "Total lines: $count" );

    return \%crisprs;
}

=head2 update_off_targets

Run the query to insert all the off target data by joining
on the temporary bed table. create_temp_tables must be run first.
This query does not update summary data

=cut
sub update_off_targets {
    my $self = shift;

    $self->log->info( 'Adding off target data' );

    #we include species twice to speed up partition search,
    #can we do this without having the id twice?
    my $query = <<EOT;
WITH ots AS (
    SELECT b.c_id AS c_id, array_agg(c.id) AS ids FROM bed b
    JOIN crisprs c ON c.chr_name=b.chr_name AND c.chr_start=b.chr_start
    WHERE c.species_id=?
    GROUP BY b.c_id
)
UPDATE crisprs 
SET off_target_ids=ots.ids
FROM ots
WHERE crisprs.id=ots.c_id AND crisprs.species_id=?
EOT

    return $self->_run_update_query( $query, $self->species_id, $self->species_id );
}

=head2 update_summaries

Run the query to insert all the summary data by joining
on the temporary summaries table. create_temp_tables must be run first.

=cut
sub update_summaries {
    my $self = shift;

    $self->log->info( "Adding summaries" );

    my $summary_query = <<EOT;
UPDATE crisprs c
SET off_target_summary=summ.summary
FROM summ
WHERE c.id=summ.c_id AND c.species_id=?
EOT

    return $self->_run_update_query( $summary_query, $self->species_id );
}

=head2 _run_update_query

Utility method to execute an update query

=cut
sub _run_update_query {
    my ( $self, $query, @bind_data ) = @_;

    my $res = $self->dbh->do( $query, undef, @bind_data );

    #if no rows are updated you get 0E0 back which isn't false
    handle_error( "No rows were updated!", $self->dbh ) 
        if ! defined $res || $res eq "0E0";

    $self->log->info ( "Updated $res rows" );

    return $res;
}

=head2 handle_error

This method will rollback the database and disconnect (then die). 
DBI calls this whenever there's a problem.
Note: not an object method (doesn't need $self)

=cut
sub handle_error {
    my ( $error, $dbh ) = @_;

    $dbh->rollback;
    $dbh->disconnect;

    die "Aborting, DB query failed:\n $error";
}

1;

__END__

=head1 NAME

WGE::Util::PersistCrisprs - persist crispr data from files

=head1 DESCRIPTION

All sites within the off target are grouped by crispr, and if the the number
of off-targets for a crispr doesn't exceed max-offs _every_ off target will be persisted,
as well as a summary string.
If there are more than max-offs only the summary will be persisted for that crispr.

The database works best with the total number of off targets in the bed file being under 200k

=head AUTHOR

Alex Hodgkins

=cut