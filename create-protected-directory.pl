#!/usr/bin/perl
use strict;
use warnings;
our $module_name;

=head1 create-protected-directory.pl

Adds protection to a directory owned by some virtual server.

This command sets up protection for a web directory under a virtual server
selected with the C<--domain> flag. The directory to protect is set with the
C<--path> flag, which can be followed by either a full path or one relative to
the domain's home directory.

The optional C<--desc> flag can be used to set the description for the directory
shown when an end user accesses it via a web browser. The password hashing
format to use can be changed from the default with one of the flags
C<--crypt>, C<--md5>, C<--sha1> or C<--digest>.

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
        $0 = "$pwd/create-protected-directory.pl";
        require './virtualmin-htpasswd-lib.pl';
        $< == 0 || die "create-protected-directory must be run as root";
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
        elsif ($a eq "--desc") {
                $desc = shift(@ARGV);
                }
	elsif ($a eq "--crypt") {
		$format = 0;
		}
	elsif ($a eq "--md5") {
		$format = 1;
		}
	elsif ($a eq "--sha1") {
		$format = 2;
		}
	elsif ($a eq "--digest") {
		$format = 3;
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
-d $path || &usage("Directory $path does not exist");
&is_under_directory($d->{'home'}, $path) ||
	&usage("Directory $path must be under $d->{'home'}");

# Check for a directory clash
my @dirs = &htaccess_htpasswd::list_directories();
my ($clash) = grep { $_->[0] eq $path } @dirs;
$clash && &usage("Directory $path is already protected");

# Check for existing files
my $file = "$path/$htaccess_htpasswd::config{'htaccess'}";
my $conf = &apache::get_htaccess_config($file);
my $htusers = $htaccess_htpasswd::config{'htpasswd'} || "htusers";
my $usersfile = "$path/$htusers";
foreach my $clash ("AuthUserFile", "AuthType", "AuthName") {
	my $dirclash = &apache::find_directive($clash, $conf);
	if ($dirclash) {
		&usage("File $file already contains Apache directive $clash");
		}
	}
-r $usersfile && &usage("Users file $usersfile already exists");
-l $file && &usage("File $file is a symbolic link");

# Create .htaccess (as domain owner)
&lock_file($file);
&apache::save_directive("AuthUserFile", [ "\"$usersfile\"" ], $conf, $conf);
&apache::save_directive("AuthType", [ "Basic" ], $conf, $conf);
if ($desc) {
	&apache::save_directive("AuthName", [ "\"$desc\"" ], $conf, $conf);
	}
&apache::save_directive("require", [ "valid-user" ], $conf, $conf);
&apache::save_directive_struct(undef, { 'name' => 'Files',
					'value' => $htusers,
					'type' => 1,
					'members' => [
					  { 'name' => 'deny',
					    'value' => 'from all' },
					],
				      }, $conf, $conf);
&virtual_server::write_as_domain_user($d,
	sub { &flush_file_lines($file) });
&unlock_file($file);
&virtual_server::set_permissions_as_domain_user($d, 0755, $file);

# Create users file
&lock_file($usersfile);
no strict "subs"; # XXX Lexical?
&virtual_server::open_tempfile_as_domain_user($d, USERS, ">$usersfile");
&virtual_server::close_tempfile_as_domain_user($d, USERS);
use strict "subs";
my $perms = &virtual_server::apache_in_domain_group($d) ? 0750 : 0755;
&virtual_server::set_permissions_as_domain_user($d, $perms, $usersfile);
&unlock_file($usersfile);

# Add to protected dirs list
my $dirstr = [ $path, $usersfile, $format, 0, undef ];
push(@dirs, $dirstr);
&htaccess_htpasswd::save_directories(\@dirs);

print "Added protection for $path\n";


sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Adds protection to a directory owned by some virtual server.\n";
print "\n";
print "virtualmin create-protected-directory --domain name\n";
print "                                      --path directory\n";
print "                                     [--desc \"description\"]\n";
print "                                     [--crypt | --md5 | --sha1 | --digest]\n";
exit(1);
}
