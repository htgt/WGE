package WGE::Util::CrisprLibrary;

use strict;
use warnings FATAL => 'all';

use WGE::Util::ExportCSV qw(format_crisprs_for_csv);
use WGE::Util::ScoreCrisprs qw(score_and_sort_crisprs);
use Data::UUID;
use Path::Class;
use Data::Dumper;
use Moose;
use POSIX qw(ceil);
use JSON;

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
    my @inputs = <$fh>;
    my $input_count = scalar @inputs;
    $self->log->debug("Getting coordinates for $input_count library targets");

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
        push @targets, { target_name => $line, target_coords => $coords };
        $progress_count++;
        $self->_update_progress('find_targets',$input_count,$progress_count);
	}
    $self->_update_job({ progress_percent => 100 });

    # Find crisprs as per search params and add to target
    # crisprs => [ $crispr1->as_hash, $crispr2->as_hash, etc  ]
    return $self->_find_crispr_sites(\@targets);
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

}

sub _coords_for_coord{
	# Just do some sanity checking and return
}

sub _find_crispr_sites{
    my ($self, $targets) = @_;

    my $count = scalar @{ $targets };
    my $progress_count = 0;
    $self->log->debug("Finding crisprs for $count targets");

    $self->_update_job({
        library_design_stage_id => 'find_crisprs',
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

    	# Rank them and take first n
    	# Store crispr list in targets hash
        $target->{crisprs} = $self->_search_crisprs(\@search_regions);

        # Update progress
        $self->_update_progress('find_crisprs',$count,$progress_count);
    }
    $self->_update_job({ progress_percent => 100 });

    return $targets;
}

sub _search_crisprs{
    my ($self, $search_regions) = @_;
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
    # FIXME: crispr ranking currently ignores crisprs missing off-target summary
    my @crisprs = score_and_sort_crisprs([ values %$crisprs ]);

    my @best = @crisprs[0..($self->num_crisprs - 1)];
    return \@best;
}

sub get_csv_data{
    my ($self) = @_;

    my @all_data;

    foreach my $target (@{ $self->targets }){
        if($target->{target_coords}->{error}){
            push @all_data, { target_name => $target->{target_name} };
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
    my $file = $self->workdir->file($filename)->spew_lines($csv_data);
    return $file;
}

sub _update_progress{
    my ($self, $stage, $total, $progress) = @_;

    # Do update every 20 records if the progress to db flag is set
    if($self->write_progress_to_db){
        if( ($progress % 20) == 0 ){
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


# Wrap update to check write to db flag before attempting to update
sub _update_job{
    my ($self, $update_params) = @_;

    if($self->write_progress_to_db){
        $self->design_job->update($update_params);
    }
    return;
}

1;