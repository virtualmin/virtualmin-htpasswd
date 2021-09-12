#!/usr/bin/perl
use strict;
use warnings;
our $module_name;

=head1 list-protected-directories.pl

Lists protected directories owned by some virtual server.

This command outputs a table of all protected web directories owned by some
virtual server, identified by the C<--domain> flag. You an also switch to a more
easily parsed format with the C<--multiline> flag, or get just a list of
directories with the C<--dir-only> flag.

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
        $0 = "$pwd/list-protected-directories.pl";
        require './virtualmin-htpasswd-lib.pl';
        $< == 0 || die "list-protected-directories must be run as root";
        }
my @OLDARGV = @ARGV;

# Parse command-line args
my ($dname, $multiline, $dironly);
while(@ARGV > 0) {
        my $a = shift(@ARGV);
        if ($a eq "--domain") {
                $dname = shift(@ARGV);
                }
        elsif ($a eq "--multiline") {
                $multiline = 1;
                }
        elsif ($a eq "--dir-only") {
                $dironly = 1;
                }
        else {
                &usage();
                }
        }

# Validate parameters
$dname || &usage("Missing --domain parameter");
my $d = &virtual_server::get_domain_by("dom", $dname);
$d || &usage("No domain named $dname found");

# List the directories for this domain
my @dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $d) } @dirs;

if ($dironly) {
	# Just the paths
	foreach my $dir (@dirs) {
		print $dir->[0],"\n";
		}
	}
elsif ($multiline) {
	# Show all details
	foreach my $dir (@dirs) {
		no warnings "once";
		my $afile = "$dir->[0]/$htaccess_htpasswd::config{'htaccess'}";
		my $conf = &apache::get_htaccess_config($afile);
		my $desc = &apache::find_directive("AuthName", $conf, 1);
		print $dir->[0],"\n";
		print "  Users file: $dir->[1]\n";
		print "  Access file: $afile\n";
		my $users = $dir->[2] == 3 ?
			&htaccess_htpasswd::list_digest_users($dir->[1]) :
			&htaccess_htpasswd::list_users($dir->[1]);
		print "  Format: ",($dir->[2] == 0 ? "Crypt" :
				    $dir->[2] == 1 ? "MD5" :
				    $dir->[2] == 2 ? "SHA1" : "Digest"),"\n";
		print "  Description: $desc\n";
		print "  User count: ",scalar(@$users),"\n";
		}
	}
else {
	# Show table
	my $fmt = "%-30.30s %-49.49s\n";
	printf $fmt, "Path", "Users file";
	printf $fmt, ("-" x 30), ("-" x 49);
	foreach my $dir (@dirs) {
		printf $fmt, $dir->[0], $dir->[1];
		}
	}

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Lists protected directories owned by some virtual server.\n";
print "\n";
print "virtualmin list-protected-directories --domain name\n";
print "                                     [--multiline | --dir-only]\n";
exit(1);
}
