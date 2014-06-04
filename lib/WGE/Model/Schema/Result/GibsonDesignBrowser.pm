package WGE::Model::Schema::Result::GibsonDesignBrowser;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::GibsonDesignBrowser::VERSION = '0.019';
}
## use critic


=head1 NAME

WGE::Model::Schema::Result::GibsonDesignBrowser

=head1 DESCRIPTION

Custom view that stores design oligo information for each design.
This is used to bring back Gibson design data for the genome browser.

Copied and adapted from LIMS2

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

__PACKAGE__->table_class( 'DBIx::Class::ResultSource::View' );

__PACKAGE__->table( 'design_browser_pairs' );

__PACKAGE__->result_source_instance->is_virtual(1);

=head Bind params
Bind params in the order:

start
end
chromosome
assembly
=cut

__PACKAGE__->result_source_instance->view_definition( <<'EOT' );
with gibsons as (select
	  a.design_oligo_id         oligo_id
	, b.design_id               design_id
    , c.design_type_id	        design_type_id
    , c.created_by              created_by
from design_oligo_loci a
	
join design_oligos b
	on (a.design_oligo_id = b.id)
join designs c
	on (b.design_id = c.id)
	and (c.design_type_id = 'gibson' or c.design_type_id = 'gibson-deletion')

where a.chr_start >= ? and a.chr_end <= ?
    and a.chr_id = ?
	and a.assembly_id = ? )
select distinct d_o.design_id		    design_id
	, d_o.id				            oligo_id
	, d_o.design_oligo_type_id	        oligo_type_id
	, d_l.assembly_id		            assembly_id
	, d_l.chr_start			            chr_start
	, d_l.chr_end			            chr_end
	, d_l.chr_id			            chr_id
	, d_l.chr_strand			        chr_strand
    , gibsons.design_type_id            design_type_id
	
from gibsons
join design_oligos d_o
	on ( gibsons.design_id = d_o.design_id )
join design_oligo_loci d_l
	on ( d_l.design_oligo_id = d_o.id )
join users u
    on ( u.id = gibsons.created_by )
where u.name = ?
order by chr_start
EOT

__PACKAGE__->add_columns(
    qw/
        oligo_id      
        assembly_id   
        chr_start     
        chr_end       
        chr_id        
        chr_strand
        design_id     
        oligo_type_id 
        design_type_id
    /
);

__PACKAGE__->set_primary_key( "oligo_id" );

__PACKAGE__->meta->make_immutable;

1;


