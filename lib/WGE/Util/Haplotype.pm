package WGE::Util::Haplotype;

use feature qw( say );

use Moose;
use namespace::autoclean;
use WGE::Util::TimeOut qw(timeout);

with 'MooseX::Log::Log4perl';

has species => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

sub retrieve_haplotypes {
	my ($self, $model, $params) = @_;
    my $line = $model->schema->resultset('Haplotype')->search(
        { name => $params->{line} }
    )->single;
	my @vcf_rs = $model->schema->resultset($line->name)->search(
        {
            chrom => $params->{chr_name},
            pos   => { '>' => $params->{chr_start}, '<' => $params->{chr_end} },
        },
        { result_class => 'DBIx::Class::ResultClass::HashRefInflator' },
    );
    return \@vcf_rs;

}

sub phase_haplotype {
    my ($self, $haplotype, $params) = @_;

    my $phased;

    my @genome_phasing = split(/:/, $haplotype->{genome_phasing});
    my @gt = split(/[\|,\/]/, $genome_phasing[0]);
    my @alleles = split(/,/, $haplotype->{alt});
    
    for my $hap ( 0 .. 1 ) {
        my $key = sprintf "haplotype_%d", $hap + 1;
        $haplotype->{$key} = $gt[$hap] ? $alleles[$gt[$hap] - 1] : 0;
    }

    $haplotype->{phased}      = $genome_phasing[0] =~ /\// ? 0 : 1;
    # unphased iff genome_phasing element contains "/"

    return $haplotype;
}

__PACKAGE__->meta->make_immutable;

1;
