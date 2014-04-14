use utf8;
package WGE::Model::Schema::Result::CrisprByExon;

=head1 NAME

WGE::Model::Schema::Result::CrisprByExon

=head1 DESCRIPTION

Custom view that selects all crisprs given a list of exons

=cut

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

__PACKAGE__->table_class( 'DBIx::Class::ResultSource::View' );
__PACKAGE__->table( 'exon_crisprs' );

__PACKAGE__->result_source_instance->is_virtual(1);

#first bound value is a postgres array exon ids (e.g. {1,2}), second is the species id
#take 22 off the chr_start so we can find crisprs that overlap start/end
#maybe add ORDER BY e.ensembl_exon_id?
#doing a join on the unnest was way quicker than doing an ANY
#we also flank the exon by 200bp
__PACKAGE__->result_source_instance->view_definition( <<'EOT' );
WITH e as ( 
    SELECT ensembl_exon_id, ((chr_start-flank)-22) as chr_start, (chr_end+flank) as chr_end, chr_name 
    FROM (SELECT unnest(?::text[]) AS id, ?::int as flank) x
    JOIN exons ON exons.ensembl_exon_id=x.id
)
SELECT e.ensembl_exon_id, c.*
FROM e
JOIN crisprs c ON c.chr_name=e.chr_name AND c.chr_start>=e.chr_start AND c.chr_start<=e.chr_end
WHERE c.species_id=?
ORDER BY c.chr_name, c.chr_start
EOT

__PACKAGE__->add_columns(
    qw(
        ensembl_exon_id
        id
        chr_name
        chr_start
        seq 
        pam_right
        species_id
        off_target_ids
        off_target_summary
    )
);

__PACKAGE__->set_primary_key( "id" );

__PACKAGE__->belongs_to(
    "species",
    "WGE::Model::Schema::Result::Species",
    { id => "numerical_id" },
);

use YAML::Any qw( Load );

#this should go in the crisprrole...
sub as_hash {
    my ( $self, $opts ) = shift;

    my @cols = qw(
        ensembl_exon_id
        id
        chr_name
        chr_start
        chr_end
        seq 
        pam_right
        species_id
        off_target_ids
        off_target_summary
    );

    my $data = { map { $_ => $self->$_ } @cols };

    #
    # this is temp -- we should switch db to store in array
    #
    if ( $self->off_target_summary ) {
        my @sum;
        #convert hash to array
        my $summary = Load( $self->off_target_summary );

        while ( my ( $k, $v ) = each %{ $summary } ) {
            $sum[$k] = $v;
        }

        $data->{off_target_summary_arr} = \@sum;
    }

    return $data;
}

with 'WGE::Util::CrisprRole';


__PACKAGE__->meta->make_immutable;

1;
