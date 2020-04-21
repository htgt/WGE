package WGE::Util::Mutability;
require Exporter;
use Carp;
use Data::Dumper;
our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/calculate_phasing/;

my %phasing = (
    q/++/ => sub {
        my ( $exon, $crispr ) = @_;
        croak "plus_plus phase $phase" if $exon->phase < 0;
        my $phased_start = $exon->chr_start + $exon->phase;
        return ($crispr->{chr_end} - $phased_start) % 3;
    },
    q/+-/ => sub {
        my ( $exon, $crispr ) = @_;
        croak "plus_minus phase $phase" if $exon->phase < 0;
        my $phased_start = $exon->chr_start + $exon->phase;
        return ($crispr->{chr_start} - $phased_start - 1) % 3;
    },
    q/-+/ => sub {
        my ( $exon, $crispr ) = @_;
        croak "minus_plus phase $phase" if $exon->end_phase < 0;
        my $phased_end = $exon->chr_end - $exon->end_phase;
        return ($phased_end - $crispr->{chr_end} + 1) % 3;
    },
    q/--/ => sub {
        my ( $exon, $crispr ) = @_;
        croak "minus_plus phase $phase" if $exon->end_phase < 0;
        my $phased_end = $exon->chr_end - $exon->end_phase;
        return ($crispr->{chr_start} - $phased_end) % 3;
    },
);

sub calculate_phasing {
    my ( $exon, $crispr ) = @_;
    my $phase = $exon->phase;
    my $cut_site = $crispr->{pam_right}
        ? $crispr->{chr_end} - 5
        : $crispr->{chr_start} + 6;
    my $exonic = ($cut_site > $exon->chr_start) && ($cut_site < $exon->chr_end);
    my $tkey = ( $exon->strand < 0 ? q/-/ : q/+/ ) . ( $crispr->{pam_right} ? q/+/ : q/-/ );
    return -1 if !$exonic || ($exon->phase < 0 && $exon->end_phase < 0);
    
    return $phasing{$tkey}->($exon, $crispr);
}

1;
