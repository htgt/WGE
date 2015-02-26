#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use WGE::Util::CrisprOffTargetPrimers;
use WGE::Model::DB;
use Getopt::Long;
use Log::Log4perl ':easy';
use Path::Class;
use Pod::Usage;
use Try::Tiny;
use Perl6::Slurp;
use YAML::Any;

my $log_level = $WARN;
my $persist = 0;
my ( $dir_name, $crispr_id, $crispr_file, $project_name );
GetOptions(
    'help'            => sub { pod2usage( -verbose => 1 ) },
    'man'             => sub { pod2usage( -verbose => 2 ) },
    'debug'           => sub { $log_level = $DEBUG },
    'verbose'         => sub { $log_level = $INFO },
    'dir=s'           => \$dir_name,
    'crispr-id=i'     => \$crispr_id,
    'crispr-file=s'   => \$crispr_file,
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );

pod2usage('Must specify a work dir --dir') unless $dir_name;

my $base_dir = dir( $dir_name )->absolute;
$base_dir->mkpath;
my $model = WGE::Model::DB->new();

my $primer_util = WGE::Util::CrisprOffTargetPrimers->new( base_dir => $base_dir );

my @crispr_ids;
if ( $crispr_id ) {
    push @crispr_ids, $crispr_id;
}
elsif ( $crispr_file ) {
    @crispr_ids = slurp $crispr_file, { chomp => 1 };
}
else {
    pod2usage( 'Provide crispr ids, --crispr-id or -crispr-file' );
}

my @failed;
for my $id ( @crispr_ids ) {
    my $crispr = try{ $model->resultset('Crispr')->find( { id => $id } ) };
    die( "Unable to find crispr group with id $id" )
        unless $crispr;

    $primer_util->crispr_off_targets_primers( $crispr );

    #dump_output( $picked_primers, $seq, $crispr );

    #push @failed, $id unless $picked_primers;
}

print Dump( { failed => \@failed } );

=head2 dump_output

Write out the generated primers plus other useful information in YAML format.

=cut
sub dump_output {
    my ( $picked_primers, $seq, $crispr ) = @_;

    unless ( $picked_primers ) {
        $picked_primers = { no_primers => 1 };
    }

    $picked_primers->{crispr_group_id}    = $crispr->id;
    $picked_primers->{gene_id}            = $crispr->gene_id;
    $picked_primers->{chromosome}         = $crispr->chr_name;
    $picked_primers->{species}            = $crispr->species;
    $picked_primers->{crispr_group_start} = $crispr->start;
    $picked_primers->{crispr_group_end}   = $crispr->end;

    my $count = 1;
    for my $cp ( @{ $crispr->ranked_crisprs } ) {
        $picked_primers->{'crispr_' . $count . '_start'} = $cp->start;
        $picked_primers->{'crispr_' . $count . '_end'}   = $cp->end;
        $picked_primers->{'crispr_' . $count . '_seq'}   = $cp->seq;
        $count++;
    }

    $picked_primers->{search_seq} = $seq->seq if $seq;

    print Dump( $picked_primers );

    return;
}


__END__

=head1 NAME

generate_crispr_off_target_primers.pl - Generate sequencing primers for crispr off targets

=head1 SYNOPSIS

  generate_crispr_off_target_primers.pl [options]

      --help                      Display a brief help message
      --man                       Display the manual page
      --debug                     Debug output
      --verbose                   Verbose output
      --dir                       Name of work directory
      --crispr-id                 ID of crispr
      --crispr-file               File with multiple crispr ids

Crispr IDs can either be specified individually or in a text file with one ID per line.

Provide a directory name where the output files will be stored.

=head1 DESCRIPTION

Generate sequencing primers for crispr off targets.

=cut
