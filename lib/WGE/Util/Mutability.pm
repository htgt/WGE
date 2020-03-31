package WGE::Util::Mutability;
require Exporter;
our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/calculate_mutability/;

my %mutability_table = (
    "++" => { 2 => 2, 1 => 1 },
    "+-" => { 2 => 2, },
    "-+" => { 0 => 2, },
    "--" => { 0 => 2, 1 => 1 },
);

sub calculate_mutability {
    my ( $exon, $crispr ) = @_;
    my $strands = ( $exon->strand   >= 0 ? q/+/ : q/-/ )
                . ( $crispr->{pam_right} ? q/+/ : q/-/ );
    my $phase = $exon->phase;
    return 0 if $exon->phase < 0 && $exon->end_phase < 0;
    my $phase = $exon->phase;
    if ( $phase < 0 ) {
        my $length = $exon->chr_end - $exon->chr_start + 1;
        if ( $exon->strand < 0 ) {
            $length = $exon->chr_start - $exon->chr_end + 1;
        }
        $phase = ($exon->end_phase - $length) % 3;
    }
    my $phased_start = $exon->chr_start - $phase + 1;
    my $position = ($crispr->{chr_end} - $phased_start) % 3;
    return (
        frame_position => $position,
        frame_value    => $mutability_table{$strands}->{$position} // 0,
    );
}

1;
