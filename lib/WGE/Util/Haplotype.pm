package WGE::Util::Haplotype;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Util::Haplotype::VERSION = '0.122';
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
    my ( $self, $model, $user, $params ) = @_;
    my $line = $model->schema->resultset('Haplotype')
        ->search( { name => $params->{line} } )->single;
    if ( not $line ) {
        die { error => 'Haplotype line not found' };
    }

    my %allowed_haplotypes = ();
    if ( $line->restricted ) {
        if ($user) {
            my $search = { user_id => $user->id, haplotype_id => $line->id };
            if ( not $model->schema->resultset('UserHaplotype')->count($search) )
            {
                die { error =>
'You do not have access to this haplotype. Contact wge@sanger.ac.uk for more information'
                };
            }
        }
        else {
            die { error => 'You must log in to see this haplotype' };
        }
    }

    my @vcf_rs = $model->schema->resultset('HaplotypeData')->search(
        {
            chrom => $params->{chr_name},
            pos   => { '>' => $params->{chr_start}, '<' => $params->{chr_end} },
        },
        {
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            from         => $line->source,
            alias        => $line->source,
        },
    );
    return \@vcf_rs;
}

sub phase_haplotype {
    my ( $self, $haplotype, $params ) = @_;

    my $phased;

    my @genome_phasing = split( /:/,       $haplotype->{genome_phasing} );
    my @gt             = split( /[\|,\/]/, $genome_phasing[0] );
    my @alleles        = split( /,/,       $haplotype->{alt} );

    for my $hap ( 0 .. 1 ) {
        my $key = sprintf "haplotype_%d", $hap + 1;
        $haplotype->{$key} = $gt[$hap] ? $alleles[ $gt[$hap] - 1 ] : 0;
    }

    $haplotype->{phased} = $genome_phasing[0] =~ /\// ? 0 : 1;

    # unphased iff genome_phasing element contains "/"

    return $haplotype;
}

__PACKAGE__->meta->make_immutable;

1;
