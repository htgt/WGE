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



    if ($params->{haplo_filter}){};

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

    my @gt_uspd16080906 = split(/:/, $haplotype->{gt_uspd16080906}); # rename gt_uspd16080906 to phasing_results in DB and code
    my @gt = split(/[\|,\/]/, $gt_uspd16080906[0]);
    my @alleles = split(/,/, $haplotype->{alt});
    unshift(@alleles, $haplotype->{ref});

    for(my $i = 0; $i < @alleles; $i++) {

        $haplotype->{haplotype_1}   = $i == $gt[0] ? $alleles[$i] : 0; # if data in $gt[0] == 0 set haplotype 1 to ref value
        $haplotype->{haplotype_2}   = $i == $gt[1] ? $alleles[$i] : 0; # if data in $gt[1] == 0 set haplotype 2 to ref value

    }

    $haplotype->{phased}        = $gt_uspd16080906[0] =~ /\|/ ? 1 : 0; # If data in gt_uspd16080906[0] contains '|' then mark phased flag 1

    return $haplotype;
}

__PACKAGE__->meta->make_immutable;

1;
