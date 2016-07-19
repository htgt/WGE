package WGE::Util::CrisprLibrary;

use strict;
use warnings FATAL => 'all';

use WGE::Util::ExportCSV qw(format_crisprs_for_csv);
use WGE::Util::ScoreCrisprs qw(score_and_sort_crisprs);
use Data::Dumper;
use Moose;

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
    $self->log->debug("Getting coordinates for library targets");
	my $fh = $self->input_fh;
	while (my $line = <$fh>){
        chomp $line;
        # remove leading/trailing whitespace
        $line =~ s/\A\s+//g;
        $line =~ s/\s+\Z//g;
        my $coords = $get_coords->($self, $line);
        push @targets, { target_name => $line, target_coords => $coords };
	}

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
    $self->log->debug("Finding crisprs for $count targets");
    foreach my $target (@{ $targets }){
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
    }

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

1;