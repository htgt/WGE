#!/usr/bin/env perl

use strict;
use warnings;

use Log::Log4perl ':easy';
use WGE::Model::DB;
use Try::Tiny;
use autodie;
use Getopt::Long;
use Pod::Usage;

BEGIN { Log::Log4perl->easy_init( { level => $DEBUG } ); }

my ( $species, $exon_id_file, $gene_id_file );
my ( $commit, $reset ) = ( 0, 0 );
GetOptions(
    "help"               => sub { pod2usage( 1 ) },
    "man"                => sub { pod2usage( 2 ) },
    "species=s"          => sub { my ( $name, $val ) = @_; $species = ucfirst(lc $val); },
    "exon-id-file=s"     => \$exon_id_file,
    "gene-id-file=s"     => \$gene_id_file,
    "reset!"             => \$reset,
    "commit!"            => \$commit, #default is to NOT commit anything.
) or die pod2usage( 2 );

die pod2usage( 2 ) unless $species and ($exon_id_file or $gene_id_file);
die "Please provide an exon file OR a gene file, not both." if $exon_id_file and $gene_id_file;

my $w = WGE::Model::DB->new;
#if reset is true we want to set the field to 0
#if reset is false (default) we set the field to 1
#! $reset doesnt work because it makes $field_val undef
my $field_val = $reset ? 0 : 1;

my $species_id = $w->resultset('Species')->find( { id => $species } )->numerical_id; 

#table specific data 
my %types = (
    exon => { file => $exon_id_file, rs_name => 'Exon', field => 'exonic' },
    gene => { file => $gene_id_file, rs_name => 'Gene', field => 'genic' }
);

{
    WARN "dry-run: nothing will be persisted" unless $commit;
    my $data = $exon_id_file ? $types{exon} : $types{gene};

    DEBUG "Updating crisprs linked to " . $data->{rs_name} . " table";

    open my $fh, "<", $data->{file};

    my $counter = 0;
    while ( my $id = <$fh> ) { 
        chomp $id;
        DEBUG "Processed $counter" if ++$counter % 1000 == 0;

        #returns a Crispr resultset
        update_crisprs( $data->{rs_name}, $data->{field}, $id );
    }

    DEBUG "Processed a total of $counter " . $data->{rs_name} . "s";
}

sub update_crisprs {
    my ( $rs_name, $field, $id ) = @_;

    $w->txn_do(
        sub {
            #get exon or gene, both have the same fields
            my $res = $w->resultset( $rs_name )->find( $id );

            die "Species " . $res->species_id . " doesn't match $species" 
                unless $res->species_id eq $species;

            my $crispr_rs = $w->resultset('Crispr')->crisprs_for_region(
                {
                    chr_name   => $res->chr_name,
                    chr_start  => $res->chr_start,
                    chr_end    => $res->chr_end,
                    species_id => $species_id,
                }
            );

            #field val is the opposite of undo (sorry)
            $crispr_rs->update( { $field => $field_val } );

            $w->txn_rollback unless $commit;
        }
    );

    return;
}

__END__

=head1 NAME

label_crisprs.pl - set all crisprs as exonic/genic for an exon/gene

=head1 SYNOPSIS

label_crisprs.pl [options]

    --species            mouse or human
    --exon-id-file       file containing exon ids 1 per line (not ensembl exon ids)
    --gene-id-file       gene containing gene ids 1 per line
    --reset              set the field to 0 instead of 1
    --commit             persist the data (default is false)
    --help               show this dialog

Example usage:

label_crisprs.pl --species human --exon-id-file human_exons.txt --commit
label_crisprs.pl --species mouse --gene-id-file mouse_ids.txt --reset --commit

=head1 DESCRIPTION

Given a file containing exon db ids or gene db ids (NOT ensembl exon ids) update 
the crisprs within the region
to be exonic/genic

Note: exonic/genic are labelled independently, so exons must be run once under genes
and once under exons to have both flags set.

This logic is duplicated in Crisprs/wge_update_crispr.pl

=head AUTHOR

Alex Hodgkins

=cut