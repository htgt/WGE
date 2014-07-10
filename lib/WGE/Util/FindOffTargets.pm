package WGE::Util::FindOffTargets;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::FindOffTargets::VERSION = '0.029';
}
## use critic


use Moose;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use WGE::Util::OffTargetServer;
use WGE::Util::GenomeBrowser qw(get_region_from_params crispr_pairs_for_region);
use Try::Tiny;
use List::MoreUtils qw(uniq);

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
        catch {
            $pair->update( { status_id => -1 } );
            $error = $_;
        };

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

sub update_region_off_targets{
    my ( $self, $model, $params ) = @_;

    # Sort the pairs so they are processed in the same order as they
    # appear in the crispr pair table
    $params->{sort_pairs} = 1;
    my $pairs = crispr_pairs_for_region($model->schema, $params);

    my @crispr_ids_to_process;
    my @pairs_to_process_now;
    my @pairs_to_process_later;

    foreach my $pair (@{ $pairs }){
    	my $pair_params = {
    		left_id  => $pair->{left_crispr}->{id},
    		right_id => $pair->{right_crispr}->{id},
    		species  => $params->{species},
    	};

    	my ( $pair, $crisprs ) = $model->find_or_create_crispr_pair( $pair_params );

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

    @crispr_ids_to_process = uniq @crispr_ids_to_process;

    my $pairs_now_pid = fork();
    if($pairs_now_pid){
    	# parent
    }
    elsif($pairs_now_pid == 0){
    	# child
    	# Calculate ots for pairs which already have crispr data
    	foreach my $pair (@pairs_to_process_now){
    		$self->log->debug("Calculating OTs for pair ".$pair->id);
    		$pair->calculate_off_targets;
    	}
    	exit 0;
    }
    else{
    	die "could not fork - $!";
    }

    my $crisprs_pid = fork();
    if($crisprs_pid){
    	# parent
    }
    elsif($crisprs_pid == 0){
    	# child
        if(@crispr_ids_to_process){
    	    # Send all crispr IDs to off-target server
    	    $self->ots_server->update_off_targets($model, { ids => [ @crispr_ids_to_process ], species => $params->{species} });
    	    # Wait and then calculate ots for pairs which have now had crispr data added
    	    foreach my $pair(@pairs_to_process_later){
    		    $self->log->debug("Calculating OTs for pair ".$pair->id);
    		    $pair->calculate_off_targets;
    	    }
        }
        exit 0;
    }
    else{
    	die "could not fork - $!";
    }

    # Return some info about what has been submitted for OT calculation
    my $crispr_count = @crispr_ids_to_process;
    my $pair_count = @pairs_to_process_now + @pairs_to_process_later;

    $self->log->debug("crispr count: $crispr_count");
    $self->log->debug("pairs to process now: ".scalar(@pairs_to_process_now));
    $self->log->debug("pairs to process later: ".scalar(@pairs_to_process_later));

    return { crispr_count => $crispr_count, pair_count => $pair_count };
}

sub update_exon_off_targets{
    my ( $self, $model, $params ) = @_;

    my $id = $params->{id};

    my $region;
    try {
        $region = get_region_from_params($model, {exon_id => $id});
    }
    catch {
        return { error_msg => "Could not get coordinates for exon $id - $_" };
    };

    # subtract 22 so we find crisprs that start before exon but end within it
    $region->{browse_start} = $region->{browse_start} - 22;

    if(defined($params->{flank})){
    	$region->{browse_start} = $region->{browse_start} - $params->{flank};
    	$region->{browse_end} = $region->{browse_end} + $params->{flank};
    }

    my $region_params = {
        start_coord => $region->{browse_start},
        end_coord   => $region->{browse_end},
        assembly_id => $region->{genome},
        chromosome_number => $region->{chromosome},
    };

    my $result = $self->update_region_off_targets($model, $region_params);
    return $result;
}

1;