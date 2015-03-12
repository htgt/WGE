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

my @summary;
for my $id ( @crispr_ids ) {
    my $crispr = try{ $model->resultset('Crispr')->find( { id => $id } ) };
    die( "Unable to find crispr group with id $id" )
        unless $crispr;

    my ( $primers, $summary ) = $primer_util->crispr_off_targets_primers( $crispr );

    dump_output( $primers, $crispr );

    push @summary, { $id => $summary } if $summary;
}

print Dump( { summary => \@summary } );

=head2 dump_output

Write out the generated primers plus other useful information in YAML format.

=cut
sub dump_output {
    my ( $ot_primer_data, $crispr ) = @_;

    unless ( @{ $ot_primer_data } ) {
        print Dump( { no_ot_primers => $crispr->id } );
        return;
    }

    for my $primers ( @{ $ot_primer_data } ) {
        my %data;

        # off target data
        $data{crispr_id}  = $crispr->id;
        $data{ot_id}      = $primers->{ot}->id;
        $data{mismatches} = $primers->{mismatches};
        $data{chromosome} = $primers->{ot}->chr_name;
        $data{start}      = $primers->{ot}->chr_start;
        $data{end}        = $primers->{ot}->chr_end;

        #primer data
        for my $type ( qw( sequencing pcr ) ) {
            if ( exists $primers->{$type} ) {
                _dump_primer_data( $primers->{$type}{'forward'}, $type, \%data );
                _dump_primer_data( $primers->{$type}{'reverse'}, $type, \%data );
            }
            else {
                $data{"no_$type"} = 1;
            }
        }
        print Dump( \%data );
    }

    return;
}

sub _dump_primer_data {
    my ( $primer, $type, $data ) = @_;
    my $oligo_type = $type . '_' . $primer->{oligo_direction};

    $data->{ $oligo_type . '_seq' } = uc( $primer->{oligo_seq} );
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
