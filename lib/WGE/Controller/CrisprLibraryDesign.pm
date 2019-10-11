package WGE::Controller::CrisprLibraryDesign;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use File::Spec::Functions;
use TryCatch;
use WGE::Util::CrisprLibrary;
use WebAppCommon::Util::JobRunner;
use WebAppCommon::Util::FileAccess;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

has file_api => (
    is         => 'ro',
    isa        => 'WebAppCommon::Util::FileAccess',
    lazy_build => 1,
);

sub _build_file_api {
    return WebAppCommon::Util::FileAccess->construct({ server => $ENV{FILE_SERVER} });
}

has job_runner => (
    is         => 'ro',
    isa        => 'WebAppCommon::Util::JobRunner',
    lazy_build => 1,
);

sub _build_job_runner {
    return WebAppCommon::Util::JobRunner->construct({ server => $ENV{FARM_SERVER} });
}

sub _logged_in {
    my ( $self, $c ) = @_;

    my $login_uri = $c->uri_for('/login');
    unless ($c->user_exists){
        $c->stash( error_msg => "You must <a href=\"$login_uri\">log in</a> to use the CRISPR Library Design Tool" );
        return 0;
    }
    return 1;
}

sub crispr_library_design :Path('/crispr_library_design') :Args(0){
	my ($self,$c) = @_;

    my @params = qw(flank_size location species num_crisprs range within flanking job_name input_from_job);

    if($c->req->param('change_file')){
        $c->stash( map { $_ => ( $c->req->param($_) // undef ) } @params );
        delete $c->stash->{input_from_job};
        return;
    }

    if($c->req->param('submit')){

    	return unless $self->_logged_in($c);


	    $c->stash( map { $_ => ( $c->req->param($_) // undef ) } @params );

	    my $species = $c->req->param('species') or _add_err($c, "You must select a species");

	    my $location_type = $c->req->param('location') or _add_err($c, "You must select a target location type");

	    my $num_crisprs = $c->req->param('num_crisprs') or _add_err($c, "You must specify how many crispr sites to find");

	    unless ($c->req->param('within') || $c->req->param('flanking')){
	    	_add_err($c, "You must specify if you want to search within and/or flanking the target locations");
	    }

	    if($c->req->param('flanking')){
	        $c->req->param('flank_size') or _add_err($c, "You must provide a flank size to search in flanking regions");
	    }

        my $input_fh;
	    if( $c->req->param('datafile') ){
            $input_fh = $c->request->upload('datafile')->fh;
        }
        elsif( my $prev_job_id = $c->req->param('input_from_job') ){
            my $old_job = $c->user->search_related('library_design_jobs', { id => $prev_job_id })->first;
            $c->log->debug("Using input file ".$old_job->input_file);
            $input_fh = IO::File->new( $old_job->input_file, "r" ) or _add_err($c, $!);
        }
        else{
            _add_err($c, "You must upload a file");
        }

	    if($c->stash->{error_msg}){
	    	return;
	    }
	    else{
            my $lib_params = {
            	model         => $c->model,
            	input_fh      => $input_fh,
                species_name  => $species,
                location_type => $location_type,
                num_crisprs   => $num_crisprs,
                within        => ( $c->req->param('within') // 0 ),
                user_id       => $c->user->id,
                write_progress_to_db => 1,
                job_name      => ( $c->req->param('job_name') || $c->req->param('datafile') ),
            };

            if($c->req->param('flanking')){
            	$lib_params->{flank_size} = $c->req->param('flank_size');
            }


            my $library = WGE::Util::CrisprLibrary->new($lib_params);
            $c->log->debug("Starting library design job with ID ".$library->job_id);

            # avoids library creation child process becoming defunct
            $SIG{CHLD} = 'IGNORE';

            my $child_pid = fork();
            if($child_pid){
                # parent forwards to user's library overview
                sleep(2); # Give the child a chance to create job in db
                $c->response->redirect( $c->uri_for('/crispr_library_jobs'));
            }
            elsif($child_pid == 0){
                my $pid = $$;
                $c->log->debug("Library creation process ID: $pid");
            	# child runs the library creation step
                try{
                    $library->write_input_data_to_file('input.txt');
                	$library->write_csv_data_to_file('WGE_crispr_library.tsv');
                }
                catch($e){
                    $c->log->debug("caught error in process $$. child process id: $pid");

                    my $update_params = { complete => 1 };
                    $library->design_job->discard_changes;
                    if(not $library->design_job->error){
                        $update_params->{error} = $e;
                    }

                    $library->design_job->update($update_params);
                    exit(1);
                }

                # Ensure child does not complete before parent does redirect
                sleep(3);
                exit;
            }
            else{
            	$c->stash->{error_msg} = "Could not fork - $!";
            }
	    }
    }

    if(my $job_id = $c->req->param('retry_job_id')){
        return unless $self->_logged_in($c);
        $self->_stash_from_previous_job($c,$job_id);
    }

    return;
}

sub crispr_library_jobs :Path('/crispr_library_jobs'){
	my ($self,$c) = @_;

    return unless $self->_logged_in($c);

    my @jobs = $c->user->library_design_jobs;
    my @sorted = sort{ $b->created_at cmp $a->created_at } @jobs;
    $c->stash->{jobs} = \@sorted;

    return;
}

sub download_library_csv :Path('/download_library_csv') :Args(1){
    my ($self, $c, $job_id) = @_;

    my $job = $c->user->search_related('library_design_jobs', { id => $job_id })->first;
    unless($job){
        $c->stash->error_msg("Could not find library design job $job_id for user ".$c->user->name);
        return;
    }

    $c->res->content_type('text/tab-separated-values');
    my $content = $self->file_api->get_file_content($job->results_file);
    $c->response->body($content);
    return;
}

sub crispr_library_job_progress :Path('/crispr_library_job_progress') :Args(1){
    my ($self, $c, $job_id) = @_;

    my $job = $c->user->search_related('library_design_jobs', { id => $job_id })->first;

    my $data;
    if($job){
        $data = {
            job_id            => $job->id,
            progress_percent  => $job->progress_percent,
            stage_id          => $job->library_design_stage_id,
            stage_description => $job->library_design_stage->description,
            complete          => $job->complete,
            error             => $job->error,
            info              => $job->info,
            last_modified     => $job->last_modified->format_cldr('yyyy-MM-dd HH:mm:ss'),
        };
    }
    $c->stash->{json_data} = $data;
    $c->forward('View::JSON');

    return;
}

sub delete_library_design_job :Path('/delete_library_design_job') :Args(1){
    my ($self, $c, $job_id) = @_;

    my $job = $c->user->search_related('library_design_jobs', { id => $job_id })->first;

    if($job){
        my $library_job_dir = $ENV{WGE_LIBRARY_JOB_DIR}
            or die "No WGE_LIBRARY_JOB_DIR environment variable set";

        my $dir = catdir($library_job_dir, $job_id);
        $self->file_api->make_dir($dir);
        my $bjob_id_file = catfile($dir, 'job_ids.txt');
        my @ids = $self->file_api->get_file_content($bjob_id_file);
        if ( @ids ) {
            foreach my $id (@ids){
                chomp($id);
                $c->log->debug("Killing job $id");
                # Catch errors and ignore those for already finished jobs
                try{
                    # FIXME: this is throwing errors even when it works and output says:
                    # Job <4834669> is being terminated
                    $self->job_runner->kill_job($id);
                }
                catch($e){
                    unless($e =~ /(already finished|No matching job found)/ ){
                        $c->flash->{error_msg} = "Could not kill farm job - $e";
                        $c->response->redirect( $c->uri_for('/crispr_library_jobs'));
                        return;
                    }
                }
            }
        }
        $job->delete;
        $self->file_api->delete_dir($dir);
    }
    else{
        $c->flash->{error_msg} = "Could not find job with ID $job_id for user ".$c->user->name;
    }

    $c->response->redirect( $c->uri_for('/crispr_library_jobs'));
    return;
}

sub _add_err{
	my ($c, $msg) = @_;
	if($c->stash->{error_msg}){
		$c->stash->{error_msg} .= "<br>$msg";
	}
	else{
		$c->stash->{error_msg} = $msg;
	}
	return;
}

sub _stash_from_previous_job{
    my ($self, $c, $job_id) = @_;

    my $job = $c->user->search_related('library_design_jobs', { id => $job_id })->first;

    if($job){
        $c->stash({
            job_name       => $job->name."_retry",
            flank_size     => $job->params->{flank_size},
            location       => $job->params->{location_type},
            species        => $job->params->{species_name},
            num_crisprs    => $job->params->{num_crisprs},
            within         => $job->params->{within},
            flanking       => $job->params->{flanking},
            input_from_job => $job_id,
            prev_job_name  => $job->name,
        });

        $c->stash->{info_msg} = "Parameters retrieved from library design job ".$job->name;
    }
    else{
        $c->stash->{error_msg} = "Could not find job with ID $job_id for user ".$c->user->name;
    }
    return;
}

1;
