package WGE::Controller::CrisprLibraryDesign;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use TryCatch;
use IO::File;
use WGE::Util::CrisprLibrary;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

sub crispr_library_design :Path('/crispr_library_design') :Args(0){
	my ($self,$c) = @_;

    if($c->req->param('submit')){

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
            };

            if($c->req->param('flanking')){
            	$lib_params->{flank_size} = $c->req->param('flank_size');
            }

            try{
                my $library = WGE::Util::CrisprLibrary->new($lib_params);
                my $csv_data = $library->get_csv_data;

                $c->stash(
                    filename     => "WGE_crispr_library.tsv",
                    data         => $csv_data,
                    current_view => 'CSV',
                );
            }
            catch($e){
            	_add_err($c, "CRISPR library generation failed with error: $e");
            };
	    }
    }

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
