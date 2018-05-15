package WGE::Util::Haplotype;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::Haplotype::VERSION = '0.114';
}
## use critic


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

	my @vcf_rs = $model->schema->resultset('VariantCallFormat')->search({
            chrom   => "chr" . $params->{chr_name},
            pos     => {'>' => $params->{chr_start}, '<' => $params->{chr_end} }
        },
        {
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        });

    return \@vcf_rs;

}

sub phase_haplotype {
    my ($self, $haplotype, $params) = @_;

    my $phased;

    my @genome_phasing = split(/:/, $haplotype->{genome_phasing});
    my @gt = split(/[\|,\/]/, $genome_phasing[0]);
    my @alleles = split(/,/, $haplotype->{alt});
    unshift(@alleles, $haplotype->{ref});

    for(my $i = 0; $i < @alleles; $i++) {

        $haplotype->{haplotype_1}   = $i == $gt[0] ? $alleles[$i] : 0; # if data in $gt[0] == 0 set haplotype 1 to ref value
        $haplotype->{haplotype_2}   = $i == $gt[1] ? $alleles[$i] : 0; # if data in $gt[1] == 0 set haplotype 2 to ref value

    }

    $haplotype->{phased}        = $genome_phasing[0] =~ /\|/ ? 1 : 0; # If data in genome_phasing[0] contains '|' then mark phased flag 1

    return $haplotype;
}

__PACKAGE__->meta->make_immutable;

1;
