package WGE::Model::Plugin::User;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $WGE::Model::Plugin::User::VERSION = '0.096';
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

sub pspec_bookmark_crispr{
	return {
        username  => { validate => 'existing_user'   },
        crispr_id => { validate => 'existing_crispr' },
        action    => { validate => 'bookmark_action' },
	};
}

sub bookmark_crispr{
	my ($self, $params) = @_;

    my $validated_params = $self->check_params( $params, $self->pspec_bookmark_crispr);
    my $user_id = $self->user_id_for($validated_params->{username});
    
    my $crispr = $self->schema->resultset('Crispr')->find({ id => $validated_params->{crispr_id} });
    if($validated_params->{action} eq 'add'){
        $crispr->link_to_user_id($user_id);
    }
    else{
    	$crispr->remove_link_to_user_id($user_id);
    }

    return;
}

sub pspec_bookmark_crispr_pair{
	return {
        username       => { validate => 'existing_user'   },
        crispr_pair_id => { validate => 'existing_crispr_pair' },
        action         => { validate => 'bookmark_action' },
	};
}

sub bookmark_crispr_pair{
	my ($self, $params) = @_;

    my $validated_params = $self->check_params( $params, $self->pspec_bookmark_crispr_pair);
    my $user_id = $self->user_id_for($validated_params->{username});
    
    my $pair = $self->schema->resultset('CrisprPair')->find({ id => $validated_params->{crispr_pair_id} });
    if($validated_params->{action} eq 'add'){
        $pair->link_to_user_id($user_id);
    }
    else{
    	$pair->remove_link_to_user_id($user_id);
    }

    return;
}
1;
