# Common functions for simple protected directory management

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
&foreign_require("virtual-server", "virtual-server-lib.pl");

# can_directory(dir, [&domain])
# Returns 1 if the current user can edit protection in the given directory
sub can_directory
{
local ($dir, $d) = @_;
if ($d) {
	# Just check specific domain
	return &is_under_directory($d->{'home'}, $dir);
	}
else {
	# Check all of his domains
	local @doms = grep { &virtual_server::can_edit_domain($_) } 
			   &virtual_server::list_domains();
	foreach my $dd (@doms) {
		return 1 if (&is_under_directory($dd->{'home'}, $dir));
		}
	return 0;
	}
}

# remove_public_html(dir, &domain)
# Returns a path relative to public_html, for display. If under cgi-bin, 
# path is relative to home
sub remove_public_html
{
local ($dir, $dom) = @_;
local $hdir = &virtual_server::public_html_dir($dom);
if ($hdir) {
	# Take relative to public_html or cgi-bin dir
	if ($hdir eq $dir) {
		return "<i>$text{'index_hdir'}</i>";
		}
	local $cdir = &virtual_server::cgi_bin_dir($dom);
	if ($dir =~ /^\Q$hdir\E\/(.*)$/) {
		return $1;
		}
	elsif ($dir =~ /^\Q$cdir\E\/(.*)$/) {
		return $1." (CGI)";
		}
	else {
		# Not under either .. return full path
		return $dir;
		}
	}
else {
	# Take relative to home
	local $hdir = $dom->{'home'};
	$dir =~ s/^\Q$hdir\E\///;
	return $dir;
	}
}

1;

