package WGE::Exception;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Exception::VERSION = '0.073';
}
## use critic

use warnings FATAL => 'all';

use Moose;
use MooseX::ClassAttribute;
use namespace::autoclean;

class_has show_stack_trace => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0
);

extends qw( Throwable::Error );

override as_string => sub {
    my ( $self ) = @_;

    my $str = $self->message;

    if ( $self->show_stack_trace ) {
        $str .= "\n\n" . $self->stack_trace->as_string;
    }

    return $str;
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;

__END__
