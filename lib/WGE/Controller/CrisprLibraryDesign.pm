package WGE::Controller::CrisprLibraryDesign;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use IO::File;
use WGE::Util::CrisprLibrary;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

sub _require_login {
    my ( $self, $c, $redirect ) = @_;

    $redirect ||= '/crispr_library_design';

    my $login_uri = $c->uri_for('/login');
    unless ($c->user_exists){
        $c->flash( error_msg => "You must <a href=\"$login_uri\">log in</a> to use the CRISPR Library Design Tool" );
        $c->res->redirect($c->uri_for($redirect));
    }
    return;
}

sub crispr_library_design :Path('/crispr_library_design') :Args(0){
	my ($self,$c) = @_;

    if($c->req->param('submit')){

    	$self->_require_login($c);

	    my @params = qw(flank_size location species num_crisprs range location within flanking);

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

	    $c->req->param('datafile') or _add_err($c, "You must upload a file");

	    if($c->stash->{error_msg}){
	    	return;
	    }
	    else{
            my $lib_params = {
            	model         => $c->model,
            	input_fh      => $c->request->upload('datafile')->fh,
                species_name  => $species,
                location_type => $location_type,
                num_crisprs   => $num_crisprs,
                within        => $c->req->param('within'),
                user_id       => $c->user->id,
                write_progress_to_db => 1,
                job_name      => $c->req->param('datafile'),
            };

            if($c->req->param('flanking')){
            	$lib_params->{flank_size} = $c->req->param('flank_size');
            }


            my $library = WGE::Util::CrisprLibrary->new($lib_params);
            $c->log->debug("Starting library design job with ID ".$library->job_id);

            my $child_pid = fork();
            if($child_pid){
                # parent forwards to user's library overview
                sleep(5); # Give the child a chance to create job in db
                $c->response->redirect( $c->uri_for('/crispr_library_jobs'));
            }
            elsif($child_pid == 0){
            	# child runs the library creation step
            	$library->write_csv_data_to_file('WGE_crispr_library.tsv');
            }
            else{
            	$c->stash->{error_msg} = "Could not fork - $!";
            }
	    }
    }

    return;
}

sub crispr_library_jobs :Path('/crispr_library_jobs'){
	my ($self,$c) = @_;

    $self->_require_login($c, '/crispr_library_jobs');

    my @jobs = $c->user->library_design_jobs;
    my @sorted = sort{ $b->created_at cmp $a->created_at } @jobs;
    $c->stash->{jobs} = \@sorted;

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
1;
