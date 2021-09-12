#!/usr/bin/perl
use strict;
use warnings;
our $module_name;

=head1 delete-protected-directory.pl

Removes protection from a directory owned by some virtual server.

This command turns off protection for a web directory, and removes all users
with access to it. The virtual server that owns the directory must be 
specified with the C<--domain> flag, and the directory path (which can be
relative to public_html) with the C<--path> flag.

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
        $0 = "$pwd/delete-protected-directory.pl";
        require './virtualmin-htpasswd-lib.pl';
        $< == 0 || die "delete-protected-directory must be run as root";
        }
my @OLDARGV = @ARGV;

# Parse command-line args
my ($dname, $path, $desc);
my $format = 0;
while(@ARGV > 0) {
        my $a = shift(@ARGV);
        if ($a eq "--domain") {
                $dname = shift(@ARGV);
                }
        elsif ($a eq "--path") {
                $path = shift(@ARGV);
                }
        else {
                &usage();
                }
        }

# Validate parameters
$dname || &usage("Missing --domain parameter");
my $d = &virtual_server::get_domain_by("dom", $dname);
$d || &usage("No domain named $dname found");
$path || &usage("Missing --path parameter");
if ($path !~ /^\//) {
	# Assume under public_html
	$path = &virtual_server::public_html_dir($d)."/".$path;
	}

# Find the directory
my @dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $d) } @dirs;
my ($dir) = grep { $_->[0] eq $path } @dirs;
$dir || &usage("Directory $path is not protected");

# Remove protection directives
no warnings "once";
my $file = "$dir->[0]/$htaccess_htpasswd::config{'htaccess'}";
&lock_file($file);
my $conf = &apache::get_htaccess_config($file);
my $htusers = $htaccess_htpasswd::config{'htpasswd'} || "htusers";
&apache::save_directive("AuthUserFile", [ ], $conf, $conf);
&apache::save_directive("AuthType", [ ], $conf, $conf);
&apache::save_directive("AuthName", [ ], $conf, $conf);
&apache::save_directive("require", [ ], $conf, $conf);
my @files = &apache::find_directive_struct("Files", $conf);
@files = grep { $_->{'value'} ne $htusers } @files;
&apache::save_directive("Files", \@files, $conf, $conf);
if ($main::file_cache{$file}) {
	&virtual_server::write_as_domain_user($d,
		sub { &flush_file_lines($file) });
	}

# Remove whole file if empty
if (&empty_file($file)) {
	&virtual_server::unlink_logged_as_domain_user($d, $file);
	}
&unlock_file($file);

# Remove htusers file
if (&can_directory($dir->[1], $d)) {
	&virtual_server::unlink_logged_as_domain_user($d, $dir->[1]);
	}

# Remove from protected dirs list
@dirs = grep { $_ ne $dir } @dirs;
&htaccess_htpasswd::save_directories(\@dirs);

print "Removed protection for $path\n";

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Removes protection from a directory owned by some virtual server.\n";
print "\n";
print "virtualmin delete-protected-directory --domain name\n";
print "                                      --path directory\n";
exit(1);
}
