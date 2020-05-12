package WGE::Util::Mutability;
require Exporter;
use Carp;
use Data::Dumper;
our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/calculate_phasing/;

sub get_positive_phase {
    my ( $exon ) = @_;
    return $exon->phase if $exon->phase >= 0;
    my $length = $exon->chr_end - $exon->chr_start + 1;
    return ($exon->end_phase - $length) % 3;
}

sub get_negative_phase {
    my ( $exon ) = @_;
    return $exon->end_phase if $exon->end_phase >= 0;
    my $length = $exon->chr_start - $exon->chr_end + 1;
    return ($exon->phase + $length) % 3;
}

my %phasing = (
    q/++/ => sub {
        my ( $exon, $crispr ) = @_;
        my $phase = get_positive_phase($exon);
        my $phased_start = $exon->chr_start + $phase;
        return ($crispr->{chr_end} - $phased_start) % 3;
    },
    q/+-/ => sub {
        my ( $exon, $crispr ) = @_;
        my $phase = get_positive_phase($exon);
        my $phased_start = $exon->chr_start + $phase;
        return ($crispr->{chr_start} - $phased_start - 1) % 3;
    },
    q/-+/ => sub {
        my ( $exon, $crispr ) = @_;
        my $phase = get_negative_phase($exon);
        my $phased_end = $exon->chr_end - $phase;
        return ($phased_end - $crispr->{chr_end} + 1) % 3;
    },
    q/--/ => sub {
        my ( $exon, $crispr ) = @_;
        my $phase = get_negative_phase($exon);
        my $phased_end = $exon->chr_end - $phase;
        return ($crispr->{chr_start} - $phased_end) % 3;
    },
);

sub calculate_phasing {
    my ( $exon, $crispr ) = @_;
    my $phase = $exon->phase;
    # 3bp before the PAM (or after, on reverse strand)
    # WGE coordinates have chr_end being 22bp after chr_start for 20bp gRNA + 3bp PAM, so, one less
    my $cut_site = $crispr->{pam_right}
        ? $crispr->{chr_end} - 5
        : $crispr->{chr_start} + 6;
    my $exonic = ($cut_site > $exon->chr_start) && ($cut_site < $exon->chr_end);
    my $tkey = ( $exon->strand < 0 ? q/-/ : q/+/ ) . ( $crispr->{pam_right} ? q/+/ : q/-/ );
    return -1 if !$exonic || ($exon->phase < 0 && $exon->end_phase < 0);
    
    return $phasing{$tkey}->($exon, $crispr);
}

1;
