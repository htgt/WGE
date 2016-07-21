package WGE::Util::PersistCrisprs::Bed;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::PersistCrisprs::Bed::VERSION = '0.097';
}
## use critic


use Moose;
with qw( WGE::Util::PersistCrisprs );

use YAML::Any qw( LoadFile );

has '+configfile' => (
    default => $ENV{WGE_REST_CLIENT_CONFIG},
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

=head2 execute

Run all the usual steps in order and commit it. This is 
just the most common usage of this module

=cut
sub execute {
    my $self = shift;

    #these will die if they fail

    #we only want to update the off targets if we have data,
    #(if no crisprs were under the max off target cutoff we have no data to persist)
    if ( $self->create_temp_tables ) {
        $self->update_off_targets;
    }

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
            $self->log->debug( "$id has " . $total_offs . " off targets." ); 
            $ots_tsv .= join( "\n", @{ $ots->{all} } ) . "\n";
        }

        #separate tsv for summary data
        $summary_tsv .= $id . "\t" . $ots->{summary} . "\n";

        #try and save SOME memory
        delete $crisprs->{ $id }; #apparently this is fine (from perl 5.8 onwards) 
    }

    #this should never happen - it would mean an empty bed file most likely
    unless ( $summary_tsv ) {
        die "No summary data, nothing to persist!";
    }

    $self->log->info( "Creating temporary summary table" );

    $self->dbh->do( "CREATE TEMP TABLE summ (c_id INTEGER, summary TEXT) ON COMMIT DROP" );
    $self->dbh->do( "COPY summ (c_id, summary) FROM STDIN" );
    $self->dbh->pg_putcopydata( $summary_tsv );
    $self->dbh->pg_putcopyend();

    $self->log->info( "Creating temporary bed table" );

    unless ( $ots_tsv ) {
        $self->log->warn( "No crisprs found with less than " . $self->max_offs . " off targets!" );
        $self->log->warn( "Only summary data will be persisted" );
        #nothing was done so return undef
        return;
    }

    #make temp table and shove all the data in
    $self->dbh->do( "CREATE TEMP TABLE bed (chr_name TEXT, chr_start INTEGER, c_id INTEGER) ON COMMIT DROP" );
    $self->dbh->do( "COPY bed (chr_name, chr_start, c_id) FROM STDIN" );
    $self->dbh->pg_putcopydata( $ots_tsv );
    $self->dbh->pg_putcopyend();
    $self->dbh->do( "CREATE INDEX idx_id ON bed (c_id)" );

    $self->log->info( "Finished temp tables" );

    #we successfully created data so return true
    return 1;
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
        $cols[1]++; #we use ensembl numbering in the db

        my $orientation = substr($cols[4], -1);
        #die "No orientation information provided" unless $orientation =~ /[LR]/;
        my $pam_right = ( $orientation eq 'R') ? 1 : 0;
        
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
    $self->log->info( "Total crisprs: " . scalar( keys %crisprs ) );
    $self->log->info( "Crisprs found: " . join( ", ", keys %crisprs ) );

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