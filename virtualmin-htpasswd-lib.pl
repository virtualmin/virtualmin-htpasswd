# Common functions for simple protected directory management
use strict;
use warnings;
our (%text);

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
&foreign_require("virtual-server", "virtual-server-lib.pl");
&foreign_require("apache", "apache-lib.pl");

# can_directory(dir, [&domain])
# Returns 1 if the current user can edit protection in the given directory
sub can_directory
{
my ($dir, $d) = @_;
if ($d) {
	# Just check specific domain
	return &is_under_directory($d->{'home'}, $dir);
	}
else {
	# Check all of his domains
	my @doms = grep { &virtual_server::can_edit_domain($_) }
			   &virtual_server::list_domains();
	foreach my $dd (@doms) {
		return 1 if (&is_under_directory($dd->{'home'}, $dir));
		}
	return 0;
	}
}

# remove_public_html(dir, &domain)
# Returns a path relative to public_html, for display. If under cgi-bin,
# path is relative to home. If under another domain's public_html dir, path
# is relative to that.
sub remove_public_html
{
my ($dir, $dom) = @_;
my $hdir = &virtual_server::public_html_dir($dom);
if ($hdir) {
	# Take relative to public_html or cgi-bin dir
	if ($hdir eq $dir) {
		return "<i>$text{'index_hdir'}</i>";
		}
	my $cdir = &virtual_server::cgi_bin_dir($dom);
	if ($dir =~ /^\Q$hdir\E\/(.*)$/) {
		return $1;
		}
	elsif ($dir =~ /^\Q$cdir\E\/(.*)$/) {
		return $1." (CGI)";
		}
	elsif ($dir =~ /^\Q$dom->{'home'}\E\/domains\/([^\/]+)/) {
		# Under a sub-server
		my $sd = &virtual_server::get_domain_by("dom", $1);
		if ($sd) {
			my $rv = &remove_public_html($dir, $sd);
			if ($rv) {
				return $rv." (".$sd->{'dom'}.")";
				}
			}
		}
	# Not under either .. return full path
	return $dir;
	}
else {
	# Take relative to home
	my $hdir = $dom->{'home'};
	$dir =~ s/^\Q$hdir\E\///;
	return $dir;
	}
}

# empty_file(filename)
# Returns true if a file contains no non-whitespace lines
sub empty_file
{
my ($file) = @_;
my $lref = &read_file_lines($file, 1);
foreach my $l (@$lref) {
	return 0 if ($l =~ /\S/);
	}
return 1;
}

1;
