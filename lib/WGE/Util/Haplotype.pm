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

	my @vcf_rs = $model->schema->resultset('VariantCallFormat')->search({
            chrom   => "chr" . $params->{chr_name},
            pos     => {'>' => $params->{chr_start}, '<' => $params->{chr_end} }
        },
        {
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        });

    return \@vcf_rs;

}

__PACKAGE__->meta->make_immutable;

1;
