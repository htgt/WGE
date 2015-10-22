#!/usr/bin/env perl -d
use strict;
use warnings FATAL => 'all';

use WGE::Util::CrisprOffTargetPrimers;
use WGE::Model::DB;
use WebAppCommon::Util::EnsEMBL;
use Getopt::Long;
use Log::Log4perl ':easy';
use Path::Class;
use Pod::Usage;
use Try::Tiny;
use Text::CSV;
use YAML::Any;
use Excel::Writer::XLSX;

my $log_level = $WARN;
my ( $dir_name, $crispr_id, $crispr_file, $max_mismatches, $project_name, $species, $persist, $file_type, $file_name );
GetOptions(
    'help'              => sub { pod2usage( -verbose => 1 ) },
    'man'               => sub { pod2usage( -verbose => 2 ) },
    'debug'             => sub { $log_level = $DEBUG },
    'verbose'           => sub { $log_level = $INFO },
    'dir=s'             => \$dir_name,
    'crispr-id=i'       => \$crispr_id,
    'crispr-file=s'     => \$crispr_file,
    'max_mismatches=i'  => \$max_mismatches,
    'species=s'         => \$species,
    'persist'           => \$persist,
    'file:s'            => \$file_type,
    'name:s'            => \$file_name,
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );

pod2usage('Must specify a work dir --dir') unless $dir_name;
die ( 'Must provide --species' ) unless $species;

my $base_dir = dir( $dir_name )->absolute;
$base_dir->mkpath;
$max_mismatches //= 3;

my $model = WGE::Model::DB->new();
my $primer_util = WGE::Util::CrisprOffTargetPrimers->new(
    base_dir                  => $base_dir,
    max_off_target_mismatches => $max_mismatches,
    persist_crisprs_lims2     => $persist,
);
my @summary;

if ( $crispr_id ) {
    generate_off_target_primers( { crispr_id => $crispr_id }, $file_type, $dir_name, $file_name);
}
elsif ( $crispr_file ) {
    my $input_csv = Text::CSV->new();
    open ( my $input_fh, '<', $crispr_file ) or die( "Can not open $crispr_file " . $! );
    $input_csv->column_names( @{ $input_csv->getline( $input_fh ) } );

    while ( my $data = $input_csv->getline_hr( $input_fh ) ) {
        generate_off_target_primers( $data, $file_type, $dir_name, $file_name );
    }
}
else {
    pod2usage( 'Provide crispr ids, --crispr-id or -crispr-file' );
}

print Dump( { summary => \@summary } );

sub generate_off_target_primers {
    my ( $crispr_data, $file_type, $dir, $file_name ) = @_;
    my $crispr = try{ $model->resultset('Crispr')->find( { id => $crispr_data->{crispr_id} } ) };
    die( "Unable to find crispr with id " . $crispr_data->{crispr_id} )
        unless $crispr;

    my ( $primers, $summary ) = $primer_util->crispr_off_targets_primers( $crispr );

    dump_output( $primers, $crispr_data, $file_type, $dir, $file_name);

    push @summary, { $crispr_data->{crispr_id} => $summary } if $summary;
}

=head2 dump_output

Write out the generated primers plus other useful information in YAML format.

=cut
sub dump_output {
    my ( $ot_primer_data, $crispr_data, $file_type, $dir, $file_name ) = @_;
    unless ( @{ $ot_primer_data } ) {
        print Dump( { no_ot_primers => $crispr_data->{crispr_id} } );
        return;
    }

    my @primer_data;
    for my $primers ( @{ $ot_primer_data } ) {
        my %data;

        # off target data
        $data{wge_crispr_id}  = $crispr_data->{crispr_id};
        $data{gene_name}  = $crispr_data->{gene_name};
        $data{wge_ot_id}  = $primers->{ot}->id;
        $data{mismatches} = $primers->{mismatches};
        $data{chromosome} = $primers->{ot}->chr_name;
        $data{start}      = $primers->{ot}->chr_start;
        $data{end}        = $primers->{ot}->chr_end;

        if ( exists $primers->{lims2_ot} ) {
            $data{lims2_crispr_id} = $primers->{lims2_ot}{crispr_id};
            $data{lims2_ot_id} = $primers->{lims2_ot}{off_target_crispr_id};
        }

        #primer data
        for my $type ( qw( sequencing pcr ) ) {
            if ( exists $primers->{$type} ) {
                _dump_primer_data( $primers->{$type}{'forward'}, $type, \%data );
                _dump_primer_data( $primers->{$type}{'reverse'}, $type, \%data );
                _inter_seq_primer_seq( $primers->{sequencing}, \%data )
                    if $type eq 'sequencing';
            }
            else {
                $data{"no_$type"} = 1;
            }
        }

        if ($file_type ne "CSV" && $file_type !~ /XLS/) {
            print Dump( \%data );
        }
        push @primer_data, \%data;
    }
    if ($file_type eq "CSV") {
        output_csv($dir, $file_name, @primer_data);
    }
    if ($file_type =~ /XLS/) {
        output_xlsx($dir, $file_name, @primer_data);
    }
    return;
}

sub _dump_primer_data {
    my ( $primer, $type, $data ) = @_;
    my $oligo_type = $type . '_' . $primer->{oligo_direction};

    $data->{ $oligo_type . '_seq' } = uc( $primer->{oligo_seq} );
}

sub _inter_seq_primer_seq {
    my ( $primers, $data ) = @_;

    my $ensembl_util = get_ensemble_util( );
    my $start = $primers->{forward}{oligo_start};
    my $end   = $primers->{reverse}{oligo_end};
    my $chr   = $data->{chromosome};

    my $slice = $ensembl_util->get_slice(
        $start, $end, $chr,
    );
    my $seq = $slice->seq;

    $data->{global_sequence} = $seq;
}

sub output_xlsx {
    my ($dir, $file_name, @primers) = @_;
    my $address = $dir . $file_name . ".xlsx";
    my $workbook = Excel::Writer::XLSX->new($address);

    my $worksheet = $workbook->add_worksheet();

    my @headers = ('Chromosome','Gene Name','WGE Crispr ID','Start','End','WGE Off Target ID','Mismatches','PCR Forward Seq','PCR Reverse Seq','Global Sequence');
    $worksheet->write_row( 'A1', \@headers );

    my $row_number = 2;
    foreach my $primer (@primers){
        my @row = (
            $primer->{chromosome},
            $primer->{gene_name},
            $primer->{wge_crispr_id},
            $primer->{start},
            $primer->{end},
            $primer->{wge_ot_id},
            $primer->{mismatches},
            $primer->{pcr_forward_seq},
            $primer->{pcr_reverse_seq},
            $primer->{global_sequence},
        );
        $worksheet->write_row('A' . $row_number, \@row);
        $row_number++;
    }
    $workbook->close;
    return;
}

sub output_csv {
    my ($dir, $file_name, @primers) = @_;
    my $address = $dir . $file_name . ".csv";
    
    my $csv = Text::CSV->new ( { binary => 1 , auto_diag => 1, eol => "\n"} )
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();
    $csv->column_names('Chromosome','Gene Name','WGE Crispr ID','Start','End','WGE Off Target ID','Mismatches','PCR Forward Seq','PCR Reverse Seq','Global Sequence');
    $csv->bind_columns();
    my $fh;
    open $fh, ">", $address or die "Failed: $!";
    $csv->print ($fh, [$csv->column_names]);

    foreach my $primer (@primers){
        my @row = (
            $primer->{chromosome},
            $primer->{gene_name},
            $primer->{wge_crispr_id},
            $primer->{start},
            $primer->{end},
            $primer->{wge_ot_id},
            $primer->{mismatches},
            $primer->{pcr_forward_seq},
            $primer->{pcr_reverse_seq},
            $primer->{global_sequence},
        );

        $csv->print($fh, \@row);
    }
    close $fh;

    return;
}

{
    my $ensembl_util;

    sub get_ensemble_util {
        unless ( $ensembl_util ) {
            $ensembl_util = WebAppCommon::Util::EnsEMBL->new( species => $species );
        }
        return $ensembl_util;
    }
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
      --max_mismatches            Max number of mismatch bases ( default 3 )
      --species                   Species of Crispr
      --persist                   Load crispr off targets into LIMS2 database
      --file                      Output file type from XLS, CSV and YAML. Default - YAML
      --name                      Name of the output file (Only XLS and CSV)

Crispr IDs can either be specified individually or in a CSV with a 'crispr_id' column.

Results sent to STDOUT in a YAML format.

You can persist the crispr off target data to LIMS2 with the '--persist' flag, make sure you
have setup the LIMS2_REST_CLIENT_CONFIG env variable first though.

This script also output the genomic sequence between the sequencing primers ( Manousous wanted this ).

Provide a directory name where the output files will be stored.

=head1 DESCRIPTION

Generate sequencing primers for crispr off targets.

=cut
