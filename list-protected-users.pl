#!/usr/bin/perl
use strict;
use warnings;
our $module_name;

=head1 list-protected-users.pl

Lists users in some protected directory.

This command outputs a table of all users with access to some protected
directory, identified by the C<--domain> flag and C<--path> flags. You an also
switch to a more easily parsed format with the C<--multiline> flag, or get just
a list of usernames with the C<--name-only> flag.

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
        $0 = "$pwd/list-protected-users.pl";
        require './virtualmin-htpasswd-lib.pl';
        $< == 0 || die "list-protected-users must be run as root";
        }
my @OLDARGV = @ARGV;

# Parse command-line args
my ($dname, $path, $multiline, $nameonly);
while(@ARGV > 0) {
        my $a = shift(@ARGV);
        if ($a eq "--domain") {
                $dname = shift(@ARGV);
                }
        elsif ($a eq "--path") {
                $path = shift(@ARGV);
                }
        elsif ($a eq "--multiline") {
                $multiline = 1;
                }
        elsif ($a eq "--name-only") {
                $nameonly = 1;
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

# Get the directories for this domain
my @dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $d) } @dirs;
my ($dir) = grep { $_->[0] eq $path ||
	           &remove_public_html($_->[0], $d) eq $path } @dirs;
$dir || &usage("Directory $path is not registered");

# Get the users for the dir
my $users = $dir->[2] == 3 ?
	&htaccess_htpasswd::list_digest_users($dir->[1]) :
	&htaccess_htpasswd::list_users($dir->[1]);

if ($nameonly) {
	# Just the usernames
	foreach my $u (@$users) {
		print $u->{'user'},"\n";
		}
	}
elsif ($multiline) {
	# Show all details
	foreach my $u (@$users) {
		print $u->{'user'},"\n";
		print "    Hashed password: $u->{'pass'}\n";
		print "    Enabled: ",($u->{'enabled'} ? "Yes" : "No"),"\n";
		}
	}
else {
	# Show table
	my $fmt = "%-40.40s %-39.39s\n";
	printf $fmt, "Username", "Hashed password";
	printf $fmt, ("-" x 40), ("-" x 39);
	foreach my $u (@$users) {
		printf $fmt, $u->{'user'}, $u->{'pass'};
		}
	}

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Lists users in some protected directory.\n";
print "\n";
print "virtualmin list-protected-users --domain name\n";
print "                                --path directory\n";
print "                               [--multiline | --name-only]\n";
exit(1);
}
