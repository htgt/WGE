package WGE::Util::CrisprLibrary;

use strict;
use warnings FATAL => 'all';

use WGE::Util::ExportCSV qw(format_crisprs_for_csv);
use WGE::Util::ScoreCrisprs qw(score_and_sort_crisprs);
use Data::UUID;
use Path::Class;
use Data::Dumper;
use Moose;
use POSIX qw(ceil sys_wait_h _exit);
use JSON;
use WGE::Util::OffTargetServer;
use List::MoreUtils qw(natatime);
use Text::CSV;
use TryCatch;

with 'MooseX::Log::Log4perl';

=head

Find crisprs within/flanking a list of specified search regions

NB: There is some overlap between this and WGE::Util::FindCrisprs which finds
crisprs and pairs for exons

=cut

has model => (
    is  => 'ro',
    isa => 'WGE::Model::DB',
    required => 1,
);

has user_id => (
    is  => 'ro',
    isa => 'Int',
    required => 0,
);

has job_name => (
    is => 'ro',
    isa => 'Str',
    default => '',
);

has input_fh => (
    is  => 'ro',
    isa => 'IO::File',
    required => 1,
);

has species_name => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has location_type => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has num_crisprs => (
    is  => 'ro',
    isa => 'Int',
    default => 1,
);

has within => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has flank_size => (
    is => 'ro',
    isa => 'Int',
    required => 0,
);

has write_progress_to_db => (
    is  => 'rw',
    isa => 'Bool',
    default => 0,
);

has update_after_n_items => (
    is  => 'rw',
    isa => 'Int',
    default => 20,
);

has species_numerical_id => (
    is => 'ro',
    isa => 'Int',
    lazy_build => 1,
);

sub _build_species_numerical_id{
    my ($self) = @_;
    my $species = $self->model->schema->resultset('Species')->search({ id => $self->species_name })->first
        or die "Could not find species ".$self->species_name;
    return $species->numerical_id;
}

has ots_server => (
    is => 'ro',
    isa => 'WGE::Util::OffTargetServer',
    lazy_build => 1,
);

sub _build_ots_server {
    return WGE::Util::OffTargetServer->new;
}

has ensembl => (
    is => 'ro',
    isa => 'WGE::Util::EnsEMBL',
    lazy_build => 1,
);

sub _build_ensembl{
	my ($self) = @_;
    # Human could be 'Human' or 'GRCh38'
    my $ens_species = ($self->species_name eq 'Mouse' ? 'mouse' : 'human' );
	return WGE::Util::EnsEMBL->new({ species => $ens_species });
}

has job_id => (
    is  => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

sub _build_job_id{
    return Data::UUID->new->create_str;
}

has workdir => (
    is  => 'ro',
    isa => 'Path::Class::Dir',
    lazy_build => 1,
);

sub _build_workdir{
    my ($self) = @_;

    my $library_job_dir = $ENV{WGE_LIBRARY_JOB_DIR}
        or die "No WGE_LIBRARY_JOB_DIR environment variable set";

    my $dir = Path::Class::Dir->new($library_job_dir, $self->job_id);
    $dir->mkpath or die "Could not create directory $dir";
    return $dir;
}

has design_job => (
    is => 'ro',
    isa => 'WGE::Model::Schema::Result::LibraryDesignJob',
    lazy_build => 1,
);

sub _build_design_job{
    my ($self) = @_;

    # find or create
    my $job = $self->model->schema->resultset('LibraryDesignJob')->find({ id => $self->job_id});

    unless($job){
        $self->user_id
            or die "CrisprLibrary user not specified - cannot create LibraryDesignJob without user";

        my $job_params = {
            species_name  => $self->species_name,
            location_type => $self->location_type,
            within        => $self->within,
            flank_size    => $self->flank_size,
            num_crisprs   => $self->num_crisprs,
        };

        $job = $self->model->schema->resultset('LibraryDesignJob')->create({
            id   => $self->job_id,
            name => $self->job_name,
            params => to_json($job_params),
            target_region_count => 0,
            created_by_id => $self->user_id,
            progress_percent => 0,
        });
    }
    return $job;
}

has crisprs_missing_offs => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub{ [] },
);

has targets => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy_build => 1,
);

sub _build_targets{
	my ($self) = @_;

    my $coord_methods = {
    	exon       => \&_coords_for_exon,
    	gene       => \&_coords_for_gene,
    	coordinate => \&_coords_for_coord,
    };

    my $get_coords = $coord_methods->{$self->location_type}
        or die "No method to get coordinates for location type ".$self->location_type;

	my @targets;
	# Go through input fh and generate a hash for each target
	# target_name   => (input from file)
	# target_coords => coords computed as required for input type
	my $fh = $self->input_fh;
    seek($fh,0,0);

    my @inputs = <$fh>;
    my $input_count = scalar @inputs;
    $self->log->debug("Getting coordinates for $input_count library targets");

    # Change the update interval for very small jobs
    if($input_count < $self->update_after_n_items){
        my $interval = ceil( $input_count / 20 );
        $self->log->debug("setting to update progress after $interval items");
        $self->update_after_n_items($interval);
    }

    $self->_update_job({
        target_region_count => $input_count,
        library_design_stage_id => 'find_targets',
        progress_percent => 0,
    });

    my $progress_count = 0;
	foreach my $line (@inputs){
        chomp $line;
        # remove leading/trailing whitespace
        $line =~ s/\A\s+//g;
        $line =~ s/\s+\Z//g;

        my $coords = $get_coords->($self, $line);
        if($coords->{error}){
            $self->_add_warning($line, $coords->{error});
        }

        push @targets, { target_name => $line, target_coords => $coords };
        $progress_count++;
        $self->_update_progress('find_targets',$input_count,$progress_count);
	}
    $self->_update_job({ progress_percent => 100 });

    # Find crisprs as per search params and add to target
    # crisprs => [ $crispr1->as_hash, $crispr2->as_hash, etc  ]

    # First pass finds crispr sites and stores IDs of any crisprs missing off-targets
    $self->_find_crispr_sites(\@targets);

    # Then we generate off targets where missing
    $self->generate_off_targets;

    # This time repeat the crispr search but sort and store the best crisprs
    return $self->_find_crispr_sites(\@targets, 1);
}

sub _coords_for_exon{
    my ($self, $exon_id) = @_;

    my $coords;

    # Try to get exon coords from wge
    my $exon = $self->model->schema->resultset('Exon')->search({
            ensembl_exon_id => $exon_id,
            'gene.species_id' => $self->species_name,
        },
        {
            prefetch => 'gene',
        })->first;

    if($exon){
        $coords = {
            start => $exon->chr_start,
            end   => $exon->chr_end,
            chr   => $exon->chr_name,
        };
    }
    else{
        # Failing that (we only have exons from canonical transcripts i think)
        # fetch it from ensembl
        $self->log->debug("Searching for exon $exon_id in ensembl");
        $exon = $self->ensembl->exon_adaptor->fetch_by_stable_id($exon_id);
        if($exon){
            $coords = {
            	start => $exon->start,
            	end   => $exon->end,
            	chr   => $exon->seq_region_name,
            };
        }
        else{
            $self->log->warn("Exon $exon_id not found in ensembl");
        	$coords = {
        		error => 'Exon not found',
        	};
        }
    }
    return $coords;
}

sub _coords_for_gene{
    my ($self, $gene_id) = @_;

    my $coords;

    # Try to find gene in WGE
    my $search_params = {
        species_id => $self->species_name,
    };

    my $is_ens_id = 0;
    if($gene_id =~ /^ENS/){
        $search_params->{ensembl_gene_id} = $gene_id;
        $is_ens_id = 1;
    }
    else{
        $search_params->{marker_symbol} = $gene_id;
    }

    my $gene = $self->model->schema->resultset('Gene')->search($search_params)->first;
    if($gene){
        $coords = {
            start => $gene->chr_start,
            end   => $gene->chr_end,
            chr   => $gene->chr_name,
        };
    }
    else{
        # Failing that fetch it from ensembl
        $self->log->debug("Searching for gene $gene_id in ensembl");
        if($is_ens_id){
            $gene = $self->ensembl->gene_adaptor->fetch_by_gene_stable_id($gene_id);
        }
        else{
            my @gene_list = @{ $self->ensembl->gene_adaptor->fetch_all_by_display_label($gene_id) || [] };
            if (@gene_list == 1){
                $gene = $gene_list[0];
            }
        }
        if($gene){
            $coords = {
                start => $gene->start,
                end   => $gene->end,
                chr   => $gene->seq_region_name,
            };
        }
        else{
            $self->log->warn("Gene $gene_id not found in ensembl");
            $coords = {
                error => 'Gene not found',
            };
        }
    }
    return $coords;
}

sub _coords_for_coord{
    my ($self, $coord_string) = @_;

    # accepts chr1:1234-1235
    # or         1:1234-1235

    my $coords;

    # remove any whitespace
    $coord_string =~ s/\s//g;
	# Just do some sanity checking and return
    my ($chr, $start_end) = split ":", $coord_string;

    unless ($chr and $start_end){
        $coords = {
            error => "Could not parse coordinate string",
        };
        return $coords;
    }

    $chr =~ s/^chr//;

    my ($start, $end) = split "-", $start_end;
    unless ($start and $end){
        $coords = {
            error => "Could not parse start and end coordinates",
        };
        return $coords;
    }

    if($start < $end){
        $coords = {
            start => $start,
            end   => $end,
            chr   => $chr,
        };
    }
    else{
        $self->log->debug("swapping start and end coords");
        $coords = {
            start => $end,
            end   => $start,
            chr   => $chr,
        };
    }

    return $coords;
}

sub _find_crispr_sites{
    my ($self, $targets, $sort_and_store) = @_;

    my $stage = 'find_crisprs';
    if($sort_and_store){
        $stage = 'rank_crisprs';
    }

    my $count = scalar @{ $targets };
    my $progress_count = 0;
    $self->log->debug("Finding crisprs for $count targets");

    $self->_update_job({
        library_design_stage_id => $stage,
        progress_percent        => 0,
    });

    foreach my $target (@{ $targets }){
        $progress_count++;
    	# Find crisprs within/flanking target region
        next if $target->{target_coords}->{error};
        my @search_regions;
        my $chr = $target->{target_coords}->{chr};
        if($self->within){
            my $search_start = $target->{target_coords}->{start};
            my $search_end = $target->{target_coords}->{end};
            if($self->flank_size){
                $search_start -= $self->flank_size;
                $search_end += $self->flank_size;
            }
            push @search_regions, {
                start => $search_start,
                end   => $search_end,
                chr   => $chr,
            };
        }
        elsif($self->flank_size){
            push @search_regions, {
                start => $target->{target_coords}->{start} - $self->flank_size,
                end   => $target->{target_coords}->{start},
                chr   => $chr,
            };

            push @search_regions, {
                start => $target->{target_coords}->{end},
                end   => $target->{target_coords}->{end} + $self->flank_size,
                chr   => $chr,
            };
        }
        else{
            die "No CRISPR site search regions requested!";
        }

        if($sort_and_store){
            # Rank them and take first n
            # Store crispr list in targets hash
            $target->{crisprs} = $self->_search_crisprs(\@search_regions, $target->{target_name}, 1);
        }
        else{
            $self->_search_crisprs(\@search_regions, $target->{target_name});
        }


        # Update progress
        $self->_update_progress($stage,$count,$progress_count);
    }
    $self->_update_job({ progress_percent => 100 });

    return $targets;
}

sub _search_crisprs{
    my ($self, $search_regions, $target, $sort_and_store) = @_;
    my $crisprs;

    # Search for any crispr starting in the search region
    # This ignores crisprs which span the region start, but includes those that span the end
    # This may need adapting based on user requirements
    foreach my $region (@{ $search_regions }){
        my $crispr_rs = $self->model->schema->resultset('Crispr')->search({
            chr_name   => $region->{chr},
            chr_start  => { '>' => $region->{start}, '<' => $region->{end} },
            species_id => $self->species_numerical_id,
        });

        foreach my $crispr( $crispr_rs->all ){
            my $crispr_hash = $crispr->as_hash;
            $crisprs->{$crispr->id} = $crispr_hash;
        }
    }
    # crispr ranking ignores crisprs missing off-target summary
    # so we need to generate any missing ones
    my @crisprs_missing_offs = grep { not defined $_->{off_target_summary} } values %$crisprs;
    my $missing_count = @crisprs_missing_offs;
    if($missing_count){
        $self->log->debug("off-target info missing for $missing_count crisprs");
        push @{ $self->crisprs_missing_offs }, map { $_->{id} } @crisprs_missing_offs;
=head
        $self->_update_job({ info => "Computing off-targets for $missing_count crisprs in $target region"});
        $self->_generate_missing_ots(\@crisprs_missing_offs);
        foreach my $crispr (@crisprs_missing_offs){
            my $id = $crispr->{id};
            my $updated_crispr = $self->model->schema->resultset('Crispr')->find({ id => $id });
            $crisprs->{ $id } = $updated_crispr->as_hash;
        }
        $self->_update_job({ info => "" });
=cut
    }

    if($sort_and_store){
        my @crisprs = score_and_sort_crisprs([ values %$crisprs ]);

        my @best = @crisprs[0..($self->num_crisprs - 1)];
        return \@best;
    }

    return [];
}

sub generate_off_targets{
    my ($self) = @_;
    my $count = scalar( @{ $self->crisprs_missing_offs} );
    if($count){
        $self->_update_job({ info => "Generating off-targets for $count crispr sites"});
        $self->_generate_missing_ots($self->crisprs_missing_offs);
        $self->_update_job({ info => '' });
    }
    return;
}

sub _generate_missing_ots{
    my ($self, $crisprs_missing_offs) = @_;

    # crisprs_missing_offs is array of cripsr->as_hash
    my $ots_species = lc($self->species_name);

    my $batch_size = 10;
    my $max_children = 5;

    my $missing_count = scalar @{$crisprs_missing_offs};

    # Ensure smaller lists of crisprs are processed in parallel
    if($missing_count < ($batch_size * $max_children) ){
        $batch_size = ceil( $missing_count / $max_children );
    }

    my $iter = natatime $batch_size, @{ $crisprs_missing_offs };
    my %pids;

    # ensure we get signals from child processes
    $SIG{CHLD} = 'DEFAULT';

    my $done = 0;
    while (my @tmp = $iter->() ){
        $self->log->debug("Starting new child process to generate off-targets");
        my $pid = fork();

        if(!defined($pid)){
            die "Could not fork - $!";
        }

        if($pid){
            # parent keeps track of child pids
            $pids{$pid} = 1;
            my $child_pid_count = keys %pids;
            $self->log->debug("Currently running $child_pid_count children");
            # Do not exceed 5 child processes
            while(keys %pids >= $max_children){
                $self->_monitor_children(\%pids);
            }
        }
        else{
            # child runs ots query

            # Child does not need the target info array so clear it to reduce mem usage
            $self->targets([]);

            #my @ids = map { $_->{id} } @tmp;
            my @ids = @tmp;
            $self->log->debug("updating off-targets for crisprs [PID: $$]: ".join ",", @ids);

            try{
                $self->ots_server->update_off_targets($self->model, { ids => \@ids, species => $ots_species } );
            }
            catch($e){
                $self->log->error("error doing OT search [PID: $$]: $e");
                $self->_update_job({ complete => 1, error => $e });
                $self->log->debug("exiting child process $$ with exit code 1");
                # Using standard exit() did not always return the exit code of 1
                # possibly due to object destructors and END routines changing $?
                # see perldocs: http://perldoc.perl.org/functions/exit.html
                # Using _exit() causes immediate exit so correct $? is seen by parent process
                _exit(1);
            }
            $self->log->debug("off-target update done [PID: $$]");
            exit(0);
        }
        $done += $batch_size;
        $self->_update_progress('off_targets',$missing_count,$done);

        sleep(2); # small delay between queries
    }
    # Wait for all pids to complete
    while(keys %pids){
        $self->_monitor_children(\%pids);
    }
    return;
}

sub _monitor_children{
    my ($self, $pids) = @_;
#$self->log->debug("monitoring children [PID: $$] ".Dumper($pids));
    my $pid = waitpid( -1, WNOHANG );
    return if $pid == -1;
    if($pid){
        my $exit_status = $? >> 8;
        $self->log->debug("Exit status of $pid: $exit_status ($?)");

        if($exit_status > 0){
            foreach my $id (keys %$pids){
                $self->log->debug("killing child process $id");
                kill(15,$id);
                delete $pids->{$id};
            }
            die "Child process $pid exited with error";
        }
        else{
            delete $pids->{$pid};
        }
    }
    sleep(1);
    return;
}

sub get_csv_data{
    my ($self) = @_;

    my @all_data;

    foreach my $target (@{ $self->targets }){
        if($target->{target_coords}->{error}){
            #push @all_data, { target_name => $target->{target_name} };
            next;
        }
        foreach my $crispr (@{ $target->{crisprs} }){
            if($crispr){
                my %crispr_info = %{ $crispr };
                $crispr_info{target_name} = $target->{target_name};
                $crispr_info{target_chromosome} = $target->{target_coords}->{chr};
                $crispr_info{target_start} = $target->{target_coords}->{start};
                $crispr_info{target_end} = $target->{target_coords}->{end};
                push @all_data, \%crispr_info;
            }
            else{
                $self->log->warn("Not enough crisprs found for target ".$target->{target_name});
            }
        }
    }

    my $extra_fields = [ qw(target_name target_chromosome target_start target_end) ];
    return format_crisprs_for_csv(\@all_data, $extra_fields);
}

sub write_csv_data_to_file{
    my ($self, $filename) = @_;

    my $csv_data = $self->get_csv_data();
    my $file = $self->workdir->file($filename);
    my $fh = $file->openw or die "Could not open file $file for writing - $!";

    foreach my $result (@$csv_data){
        print $fh join "\t", @$result;
        print $fh "\n";
    }
    close $fh;

    $self->_update_job({ complete => 1, results_file => "$file" });

    return $file;
}

sub write_input_data_to_file{
    my ($self, $filename) = @_;

    my $file = $self->workdir->file($filename);
    my $out_fh = $file->openw or die "Could not open file $file for writing - $!";

    my $in_fh = $self->input_fh;
    seek($in_fh,0,0);

    foreach my $line(<$in_fh>){
        print $out_fh $line;
    }

    $self->_update_job({ input_file => "$file" });

    return $file;
}

sub _update_progress{
    my ($self, $stage, $total, $progress) = @_;

    # Do update every n records if the progress to db flag is set
    if($self->write_progress_to_db){
        if( ($progress % $self->update_after_n_items) == 0 ){
            my $percent  = ceil( ($progress / $total) * 100 );
            $self->design_job->update({
                library_design_stage_id => $stage,
                progress_percent        => $percent,
            });
            $self->log->debug("Progress updated to $stage $percent%");
        }
    }
    return;
}

sub _add_warning{
    my ($self, $target_name, $warning) = @_;

    if($self->write_progress_to_db){
        my $warning_from_db = $self->design_job->warning // "" ;
        my $new_warning = $warning_from_db."<br>$target_name: ".$warning;
        $self->design_job->update({ warning => $new_warning });
    }
    return;
}

# Wrap update to check write to db flag before attempting to update
sub _update_job{
    my ($self, $update_params) = @_;

    if($self->write_progress_to_db){
        $self->design_job->update($update_params);
    }
    return;
}

1;