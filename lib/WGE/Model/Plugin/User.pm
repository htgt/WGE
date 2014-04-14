package WGE::Model::Plugin::User;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Plugin::User::VERSION = '0.011';
}
## use critic


use Moose::Role;
use Hash::MoreUtils qw(slice_def);
use Log::Log4perl qw( :easy );

sub user_id_for{
    my ($self, $name) = @_;

    my $user = $self->schema->resultset('User')->find({ name => $name})
        or $self->throw( NotFound => "User $name does not exist");
    return $user->id;
}

1;
