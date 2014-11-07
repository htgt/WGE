package WGE::Exception::Validation;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Exception::Validation::VERSION = '0.053';
}
## use critic

use warnings FATAL => 'all';

use Moose;
use MooseX::ClassAttribute;
use Data::Dump qw( pp );
use namespace::autoclean;

extends qw( WGE::Exception );

has show_params => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1
);

has '+message' => (
    default => 'Parameter validation failed'
);

has results => (
    is  => 'ro',
    isa => 'Data::FormValidator::Results',
);

has params => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

override as_string => sub {
    my $self = shift;

    my $str = $self->message;

    my $res = $self->results;

    if ( defined $res ) {

        my @errors;

        if ( $res->has_missing ) {
            for my $f ( $res->missing ) {
                push @errors, "$f, is missing";
            }
        }

        if ( $res->has_invalid ) {
            for my $f ( $res->invalid ) {
                push @errors, "$f, is invalid: " . join q{,}, @{ $res->invalid( $f ) };
            }
        }

        if ( $res->has_unknown ) {
            for my $f ( $res->unknown ) {
                push @errors, "$f, is unknown";
            }
        }

        $str = join "\n\t", $str, @errors;
    }

    if ( $self->show_params and %{ $self->params } ) {
        $str .= "\n\n" . pp( $self->params );
    }

    if ( $self->show_stack_trace ) {
        $str .= "\n\n" . $self->stack_trace->as_string;
    }

    return $str;
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;

__END__
