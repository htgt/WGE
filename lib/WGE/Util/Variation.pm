package WGE::Util::Variation;

use feature qw( say );

use Moose;
use namespace::autoclean;
use WGE::Util::EnsEMBL;

with 'MooseX::Log::Log4perl';

has species => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has ensembl => (
    is         => 'rw',
    isa        => 'WGE::Util::EnsEMBL',
    lazy_build => 1,
    handles    => [ 'variation_feature_adaptor', 'slice_adaptor' ],
);

sub _build_ensembl {
    my $self = shift;

    return WGE::Util::EnsEMBL->new( species => $self->species );
}

=head variation_for_region

Returns all variation feature for a region that have a MAF score assigned

=cut

sub variation_for_region {
    my $self = shift;
    my $model = shift;
    my $params = shift;

    my @vf_mafs;

    my $pid = $$;
    my $time = 5;

    my $alarm_pid = fork();
    if($alarm_pid == 0){
        # child monitors parent and kills it if it takes too long
        for (1..$time) { sleep 1; kill(0,$pid) || exit }
        $self->log->error("variation_for_region has timed out - killing process $pid");
        kill 'KILL', $pid;
        exit;
    }

    # parent does the work
    my $slice_adaptor = $self->slice_adaptor( $params->{'species'} );
$self->log->debug("getting slice");
    my $slice = $slice_adaptor->fetch_by_region(
        'chromosome',
        $params->{'chr_number'},
        $params->{'start_coord'},
        $params->{'end_coord'},
    );
$self->log->debug("got slice");

    my $vf_adaptor = $self->variation_feature_adaptor( $params->{'species'} );
$self->log->debug("getting variation features");
    my $vfs = $vf_adaptor->fetch_all_by_Slice( $slice );
$self->log->debug("got ".scalar @{$vfs}." variation features");

    my @req_keys
        = qw/
            variation_name
            allele_string
            class_SO_term
            minor_allele_frequency
            minor_allele
            minor_allele_count
            source
            strand
          /;

$self->log->debug("getting minor allele frequencies");
    foreach my $vf ( @{$vfs}) {
        if ( $vf->minor_allele_frequency ) {
            my %maff = map { $_ => $vf->$_ } @req_keys;
            $maff{'start'} = $vf->transform('chromosome')->start;
            $maff{'end'} = $vf->transform('chromosome')->end;
            push @vf_mafs, \%maff;
        }
    }
$self->log->debug("got minor allele frequencies");
    # Parent kills the child alarm process now that the work is complete
    kill 'KILL', $alarm_pid;

    return \@vf_mafs;
}

__PACKAGE__->meta->make_immutable;

1;

