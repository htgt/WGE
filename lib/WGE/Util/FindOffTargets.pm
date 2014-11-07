package WGE::Util::FindOffTargets;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::FindOffTargets::VERSION = '0.053';
}
## use critic


use Moose;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use WGE::Util::OffTargetServer;
use WGE::Util::GenomeBrowser qw(get_region_from_params crispr_pairs_for_region crisprs_for_region);
use TryCatch;
use List::MoreUtils qw(uniq);
use LIMS2::Exception;

has log => (
    is         => 'rw',
    isa        => 'Log::Log4perl::Logger',
    lazy_build => 1
);

sub _build_log {
    require Log::Log4perl;
    return Log::Log4perl->get_logger("WGE");
}

has ots_server => (
    is => 'ro',
    isa => 'WGE::Util::OffTargetServer',
    lazy_build => 1,
);

sub _build_ots_server {
    return WGE::Util::OffTargetServer->new;
}

sub run_individual_off_target_search {
    my ( $self, $model, $species, $ids ) = @_;

    #make sure we got SOMETHING in ids
    LIMS2::Exception->throw( "No ids provided" ) unless $ids;

    if ( ref $ids eq 'ARRAY' ) {
        LIMS2::Exception->throw( "No ids provided" ) unless @{ $ids };
    }
    else {
        #its probably a scalar, so put it in an arrayref
        $ids = [ $ids ];
    }

    if ( @{$ids} > 100 ) {
        LIMS2::Exception->throw( "Can only search for 100 crispr off targets at a time" );
    }

    #find all ids that don't have
    my @data_missing = grep { ! $_->off_target_summary }
                         $model->schema->resultset('Crispr')->search( { id => {-IN => $ids} } );

    return unless @data_missing;

    my $db_species = $data_missing[0]->species->id;

    if ( $db_species ne $species ) {
        LIMS2::Exception->throw( "Provided species ($species) does not match CRISPR species ($db_species)!" );
    }

    $self->ots_server->update_off_targets($model, { ids => [ map { $_->id } @data_missing ], species => $species } );
}

sub run_pair_off_target_search{
	my ($self, $model, $params) = @_;

    my ( $pair, $crisprs ) = $model->find_or_create_crispr_pair( $params );

    #see what the current pair status is, and decide what to do

    #if its -2 we want to skip, not continue
    if ( $pair->status_id > 0 ) {
        #LOG HERE
        #someone else has already started this one, so don't do anything
        return { 'error' => 'Job already started!' };
    }
    elsif ( $pair->status_id == -2 ) {
        #skip it!
        return { 'error' => 'Pair has bad crispr' };
    }

    #pair is ready to start

    #its now pending so update the db accordingly
    $pair->update( { status_id => 1 } );

    #if we already have the crisprs pass them on so the method doesn't have to
    #fetch them again
    my @ids_to_search = $pair->_data_missing( $crisprs );

    my $data;
    if ( @ids_to_search ) {
        $self->log->warn( "Finding off targets for: " . join(", ", @ids_to_search) . " (".$pair->get_species.")" );
        my $error;
        try {
            die "No pair id" unless $pair->id;
            #we now definitely have a pair, so we would begin the search process

            $self->ots_server->update_off_targets($model,{ ids => \@ids_to_search, species => $pair->get_species });
            $pair->calculate_off_targets;
        }
        catch ($e){
            $pair->update( { status_id => -1 } );
            $error = $e;
        }

        if ( $error ) {
            $self->log->warn( "Error getting off targets:" . $error );
            $data = { success => 0, error => $error };
        }
        else {
            $data = { success => 1 };
        }
    }
    else {
        $self->log->debug( "Individual crisprs already have off targets, calculating paired offs" );
        #just calculate paired off targets as we already have all the crispr data
        $pair->calculate_off_targets;
        $data = { success => 1 };
    }

    $data->{pair_status} = $pair->status_id;
    return $data;
}

# Provide $c if you call this from the webapp
# as child processes must detach the request
sub update_region_off_targets{
    my ( $self, $model, $params, $c ) = @_;

    $self->log->debug("Searching for region off-targets: ".Dumper($params));

    #we use both... need to tidy this all up really
    if ( ! $params->{species_id} ) {
        $params->{species_id} = $params->{species};
    }

    # Sort the pairs so they are processed in the same order as they
    # appear in the crispr pair table
    $params->{sort_pairs} = 1;
    my $pairs = crispr_pairs_for_region($model->schema, $params);

    my @crispr_ids_to_process;
    my @pairs_to_process_now;
    my @pairs_to_process_later;
    my %crispr_id_seen;

    foreach my $pair (@{ $pairs }){
    	my $pair_params = {
    		left_id  => $pair->{left_crispr}->{id},
    		right_id => $pair->{right_crispr}->{id},
    		species  => $params->{species},
    	};

        # Store IDs so we don't process them again as individual crisprs
        $crispr_id_seen{$pair->{left_crispr}->{id}} = 1;
        $crispr_id_seen{$pair->{right_crispr}->{id}} = 1;

    	my ( $pair, $crisprs );
        try{
            ( $pair, $crisprs ) = $model->find_or_create_crispr_pair( $pair_params );
        }
        catch($e){
            return { error_msg => "Could not find or create crispr pair "
                                  .$pair->{left_crispr}->{id}."_".$pair->{right_crispr}->{id}
                                  .". Error: $e" };
        }

        #see what the current pair status is, and decide what to do

        #if its -2 we want to skip, not continue
        if ( $pair->status_id > 0 ) {
            #someone else has already started this one, so don't do anything
            next;
        }
        elsif ( $pair->status_id == -2 ) {
            #pair has bad crispr - skip it!
            next;
        }

        #its now pending so update the db accordingly
        $pair->update( { status_id => 1 } );

        #if we already have the crisprs pass them on so the method doesn't have to
        #fetch them again
        my @ids_to_search = $pair->_data_missing( $crisprs );

        if(@ids_to_search){
            push @crispr_ids_to_process, @ids_to_search;
            push @pairs_to_process_later, $pair;
        }
        else{
            push @pairs_to_process_now, $pair;
        }
    }

    if($params->{all_singles}){
        # Get IDs of any crisprs which we have not already seen in a pair
        my $crispr_rs = crisprs_for_region($model->schema,$params);
        my $unpaired_crispr_rs = $crispr_rs->search({ id => {'not in' => [ keys %crispr_id_seen ]} });

        #  and which do not already have ot summary
        while (my $crispr = $unpaired_crispr_rs->next){
            unless ( defined $crispr->get_column( 'off_target_summary' ) ){
                push @crispr_ids_to_process, $crispr->id;
            }
        }
    }

    @crispr_ids_to_process = uniq @crispr_ids_to_process;

    # Return some info about what has been submitted for OT calculation
    my $crispr_count = @crispr_ids_to_process;
    my $pair_count = @pairs_to_process_now + @pairs_to_process_later;

    $self->log->debug("crispr count: $crispr_count");
    $self->log->debug("pairs to process now: ".scalar(@pairs_to_process_now));
    $self->log->debug("pairs to process later: ".scalar(@pairs_to_process_later));

    if($crispr_count > 100){
        # reset pair status to "not started" before die
        foreach my $pair (@pairs_to_process_now, @pairs_to_process_later){
            $pair->update( { status_id => 0 } );
        }
        die "Will not submit $crispr_count crisprs for off-target calculation (maximum: 100 crisprs). Please submit a smaller region.\n";
    }

    # Parent will not wait for child processes
    # Don't create zombie processes
    local $SIG{CHLD} = 'IGNORE';

    $self->log->debug("Starting first forked process");
    my $pairs_now_pid = fork();
    if($pairs_now_pid){
    	# parent
        $self->log->debug("Pair OT processing pid: $pairs_now_pid");
    }
    elsif($pairs_now_pid == 0){
    	# child
        sleep 1; # pause so child doesn't detach before parent
        $self->log->debug("child process for pairs");
        $model->clear_schema; # Force re-connect

    	# Calculate ots for pairs which already have crispr data
    	foreach my $pair (@pairs_to_process_now){
    		$self->log->debug("Calculating OTs for pair ".$pair->id);
            try{
    		    $pair->calculate_off_targets;
            }
            catch ($e){
                $self->log->debug("region off-target first child process error for pair ".$pair->id.": $e");
            }
    	}
        _detach_request($c);
    	exit 0;
    }
    else{
    	die "could not fork - $!";
    }

    $self->log->debug("Starting second forked process");
    my $crisprs_pid = fork();
    if($crisprs_pid){
    	# parent
        $self->log->debug("Crispr OT processing pid: $crisprs_pid");
    }
    elsif($crisprs_pid == 0){
    	# child
        sleep 1; # pause so child doesn't detach before parent
        $self->log->debug("child process for crisprs");
        $model->clear_schema; # Force re-connect

        if(@crispr_ids_to_process){
    	    # Send all crispr IDs to off-target server
            try{
    	        $self->ots_server->update_off_targets($model, { ids => [ @crispr_ids_to_process ], species => $params->{species} });
            }
            catch ($e){
                $self->log->debug("region off-target second child process error submitting individual crisprs: $e");
                _detach_request($c);
                exit 0;
            }
    	    # Wait and then calculate ots for pairs which have now had crispr data added
    	    foreach my $pair(@pairs_to_process_later){
    		    $self->log->debug("Calculating OTs for pair ".$pair->id);
                try{
                   $pair->calculate_off_targets;
                }
                catch ($e){
                   $self->log->debug("region off-target second child process error for pair ".$pair->id.": $e");
                }
    	    }
        }
        _detach_request($c);
        exit 0;
    }
    else{
    	die "could not fork - $!";
    }
    $self->log->debug("Returning from OT search parent process");
    return { crispr_count => $crispr_count, pair_count => $pair_count };
}

# Provide $c if you call this from the webapp
# as child processes must detach the request
sub update_exon_off_targets{
    my ( $self, $model, $params, $c ) = @_;

    $self->log->debug("Searching for exon off-targets: ".Dumper($params));

    my $region;
    try {
        $region = get_region_from_params( $model, $params );
    }
    catch ($e) {
        return { error_msg => "Could not get coordinates for exon " . $params->{exon_id} . " - $e" };
    }

    # subtract 22 so we find crisprs that start before exon but end within it
    $region->{browse_start} = $region->{browse_start} - 22;

    if(defined($params->{flank})){
    	$region->{browse_start} = $region->{browse_start} - $params->{flank};
    	$region->{browse_end} = $region->{browse_end} + $params->{flank};
    }

    my $region_params = {
        species_id  => $params->{species_id},
        start_coord => $region->{browse_start},
        end_coord   => $region->{browse_end},
        assembly_id => $region->{genome},
        chromosome_number => $region->{chromosome},
    };

    my $result = $self->update_region_off_targets($model, $region_params, $c);
    return $result;
}

sub _detach_request{
    my ($c) = @_;
    if($c){
        $c->detach();
    }
    return;
}
1;