package WGE::Model::Schema::Result::HaplotypeData;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Schema::Result::HaplotypeData::VERSION = '0.127';
}
## use critic

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

__PACKAGE__->table('HaplotypeData');

__PACKAGE__->add_columns(
  id             => { data_type => "integer", is_nullable => 0, },
  chrom          => { data_type => "text", is_nullable => 0 },
  pos            => { data_type => "integer", is_nullable => 0 },
  ref            => { data_type => "text", is_nullable => 0 },
  alt            => { data_type => "text", is_nullable => 0 },
  qual           => { data_type => "numeric", is_nullable => 1 },
  filter         => { data_type => "text", is_nullable => 1 },
  genome_phasing => { data_type => "text", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->meta->make_immutable;
1;

