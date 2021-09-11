#!/usr/bin/perl
use strict;
use warnings;
our $module_name;

=head1 create-protected-user.pl

Add a user to some protected directory.

This command adds a user to a protected directory, identified by the C<--domain>
and C<--path> flags. The login for the new user must be set with C<--user>,
and the initial password with the C<--pass> flag (or C<--encpass> if you have
a pre-hashed password in the right format). To create a user that is initially
blocked from logging in, use the C<--disabled> flag.

=cut

package virtualmin_htpasswd;
if (!$module_name) {
        no warnings "once";
        $main::no_acl_check++;
        use warnings "once";
        $ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
        $ENV{'WEBMIN_VAR'} ||= "/var/webmin";
        my $pwd;
        if ($0 =~ /^(.*)\/[^\/]+$/) {
                chdir($pwd = $1);
                }
        else {
                chop($pwd = `pwd`);
                }
        $0 = "$pwd/created-protected-user.pl";
        require './virtualmin-htpasswd-lib.pl';
        $< == 0 || die "create-protected-user must be run as root";
        }
my @OLDARGV = @ARGV;

# Parse command-line args
my ($dname, $path, $user, $pass, $encpass);
my $enabled = 1;
while(@ARGV > 0) {
        my $a = shift(@ARGV);
        if ($a eq "--domain") {
                $dname = shift(@ARGV);
                }
        elsif ($a eq "--path") {
                $path = shift(@ARGV);
                }
        elsif ($a eq "--user") {
                $user = shift(@ARGV);
                }
        elsif ($a eq "--pass") {
                $pass = shift(@ARGV);
                }
        elsif ($a eq "--encpass") {
                $encpass = shift(@ARGV);
                }
        elsif ($a eq "--enabled") {
                $enabled = 1;
                }
        elsif ($a eq "--disabled") {
                $enabled = 0;
                }
        else {
                &usage();
                }
        }

# Validate parameters
$dname || &usage("Missing --domain parameter");
$path || &usage("Missing --directory parameter");
my $d = &virtual_server::get_domain_by("dom", $dname);
$d || &usage("No domain named $dname found");
$user || &usage("Missing --user parameter");
$pass || $encpass || &usage("Missing --pass or --encpass parameter");

# Get the directories for this domain
my @dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $d) } @dirs;
my ($dir) = grep { $_->[0] eq $path ||
	           &remove_public_html($_->[0], $d) eq $path } @dirs;
$dir || &usage("Directory $path is not registered");

# Get the current users for the dir and check for a clash
my $users = $dir->[2] == 3 ?
	&htaccess_htpasswd::list_digest_users($dir->[1]) :
	&htaccess_htpasswd::list_users($dir->[1]);
my ($clash) = grep { $_->{'user'} eq $user } @$users;
$clash && &usage("A user named $user already exists");

# Add a new user object
my $suser = { 'user' => $user,
	      'dom' => $d->{'dom'},
	      'enabled' => $enabled };
if ($encpass) {
	$suser->{'pass'} = $encpass;
	}
else {
	$suser->{'pass'} = &htaccess_htpasswd::encrypt_password(
		$pass, undef, $dir->[2]);
	}
&virtual_server::write_as_domain_user($d,
	sub { &htaccess_htpasswd::create_user($suser, $dir->[1]) });
print "Created $suser->{'user'} in $dir->[1]\n";

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Add a user to some protected directory.\n";
print "\n";
print "virtualmin create-protected-user --domain name\n";
print "                                 --path directory\n";
print "                                 --user username\n";
print "                                [--pass password | --encpass hash]\n";
print "                                [--enabled | --disabled]\n";
exit(1);
}
