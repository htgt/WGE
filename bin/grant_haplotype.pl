#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage qw/pod2usage/;
use WGE::Model::DB;

my ( $domain, $user_file, $haplotype, $dry_run, $help );
GetOptions(
    'domain=s' => \$domain,
    'users=s'  => \$user_file,
    'line=s'   => \$haplotype,
    'dry-run'  => \$dry_run,
    'help|?'   => \$help,
) or pod2usage(2);
if ($help) {
    pod2usage( -verbose => 2 );
}
die "Missing required argument --users"     if not defined $user_file;
die "Missing required argument --haplotype" if not defined $haplotype;
open my $fh, '<', $user_file or die 'Could not open user file';
chomp( my @emails = <$fh> );
close $fh;

if ($domain) {
    foreach my $email (@emails) {
        next if $email =~ m/@/;
        $email = join '@', $email, $domain;
    }
}

my $model = WGE::Model::DB->new;
my $line =
  $model->schema->resultset('Haplotype')->search( { name => $haplotype } )
  ->single;
die "Cannot find line '$haplotype'" if not $line;

my $search = { name => { -in => \@emails } };
my %users =
  map { $_->name => $_->id }
  $model->schema->resultset('User')->search($search)->all;

foreach my $email (@emails) {
    if ( not exists $users{$email} ) {
        print "Cannot find user '$email'\n";
        next;
    }
    my $user = $users{$email};
    if ( not $dry_run ) {
        $model->schema->resultset('UserHaplotype')->find_or_create(
            {
                user_id      => $user,
                haplotype_id => $line->id,
            }
        );
    }
    printf "GRANT %s TO %s (%d)\n", $line->name, $email, $user;
}

__END__

=head1 NAME

grant_haplotype.pl - Grants users access to haplotypes

=head1 SYNOPSIS

grant_haplotype.pl --users F<PATH> --line B<TEXT> [<OPTIONS...>]

=head1 ARGUMENTS

=over 4

=item B<-u --users> <PATH>

A file contianing a list of users to grant access to a haplotype.

=item B<-l --line> <TEXT>

The name of a haplotype to grant the users access to.

=back

=head1 OPTIONS

=over 4

=item B<--domain> <TEXT>

If specified, appends @<TEXT> to each entry in the text file who does not contain one.
So you if you have a text file F<users.txt> containing:

=over 4

=item ab1

=item cd2

=item jane.smith@example.org

=back

Then run with C<--users users.txt --domain example.com> then the following users will get access:

=over 4

=item ab1@example.com

=item cd2@example.com

=item jane.smith@example.org

=back

=item B<--dry-run>

Show what will happen, without actually doing it

=back

