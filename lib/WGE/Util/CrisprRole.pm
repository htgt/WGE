package WGE::Util::CrisprRole;

use Moose::Role;

requires qw( chr_start pam_right );

#these methods are required by multiple resultsets,
#to use them just add 
#with 'WGE::Util::CrisprRole'

#CHECK THESE NUMBERS!! we want either the start or end of sgrna
sub pam_start {
    my $self = shift;
    return $self->chr_start + ($self->pam_right ? 19 : 2)
}

sub pam_left {
    return ! shift->pam_right;
}

1;