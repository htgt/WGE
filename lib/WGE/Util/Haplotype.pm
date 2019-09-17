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

use Data::Dumper;
sub _is_line_visible {
    my ( $line, $user_haplotypes ) = @_;
    my $restricted = grep { $_ eq q/*/ } @{$line->restricted};
    return (not $restricted) || (exists $user_haplotypes->{$line->id}); 
}

sub _get_user_lines {
    my ( $model, $user ) = @_;
    my %user_lines = ();
    if ( $user ) {
        my $search = { user_id => $user->id };
        %user_lines = map { $_->haplotype_id => 1 }
            $model->schema->resultset('UserHaplotype')->search($search);
    }
    return \%user_lines;
}

sub visible_lines {
    my ( $self, $model, $user ) = @_;
    my $user_lines = _get_user_lines($model, $user);
    return map { $_->name => _is_line_visible( $_, $user_lines ) ? 1 : 0 }
        $model->schema->resultset('Haplotype')->search({ species_id => $self->species });
}

sub retrieve_haplotypes {
    my ( $self, $model, $user, $params ) = @_;
    my $line = $model->schema->resultset('Haplotype')
        ->search( { name => $params->{line} } )->single;
    if ( not $line ) {
        die "Haplotype line not found\n";
    }
    my $chrom = $params->{chr_name};

    my %allowed_haplotypes = ();
    my %haplotype_restricted_for_chroms = ( q/*/ => 1, $chrom => 1 );
    if ( grep { exists $haplotype_restricted_for_chroms{$_} } @{$line->restricted} ) {
        if ($user) {
            my $search = { user_id => $user->id, haplotype_id => $line->id };
            if ( not $model->schema->resultset('UserHaplotype')->count($search) )
            {
                die "You do not have access to this haplotype. Contact wge\@sanger.ac.uk for more information\n";
            }
        }
        else {
            die "You must log in to see this haplotype\n";
        }
    }

    my @vcf_rs = $model->schema->resultset('HaplotypeData')->search(
        {
            chrom => $chrom,
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
