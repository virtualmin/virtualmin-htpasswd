#!/usr/local/bin/perl
# Add protection

require './virtualmin-htpasswd-lib.pl';
&ReadParse();
&error_setup($text{'add_err'});

# Validate inputs
$d = &virtual_server::get_domain($in{'dom'});
&virtual_server::can_edit_domain($d) || &error($text{'index_ecannot'});
$pub = &virtual_server::public_html_dir($d);
$cgi = &virtual_server::cgi_bin_dir($d);
if ($in{'dir_def'} == 1) {
	# Whole website
	$dir = $pub;
	}
else {
	$dirname = $in{'dir_def'} == 2 ? $in{'cgi'} : $in{'dir'};
	$dirname =~ /\S/ || &error($text{'add_edir'});
	$dirname !~ /\.\./ && $dirname !~ /\0/ ||
		&error($text{'add_edir2'});
	$dirname !~ /^\// || &error($text{'add_edir3'});
	if ($in{'dir_def'} == 2) {
		# Under cgi-bin
		$dir = $cgi."/".$in{'cgi'};
		}
	else {
		# Under public_html
		$dir = $pub."/".$in{'dir'};
		}
	-d $dir || &error($text{'add_edir4'});
	}
$in{'desc'} =~ /\S/ || &error($text{'add_edesc'});

# Check for existing files
$file = "$dir/$htaccess_htpasswd::config{'htaccess'}";
-r $file && &error(&text('add_eclash', $file));
$usersfile = "$dir/htusers";
-r $usersfile && &error(&text('add_eclash2', $usersfile));

# Create .htaccess (as domain owner)
&open_lock_tempfile(HTACCESS, ">$file");
&print_tempfile(HTACCESS, "AuthUserFile \"$usersfile\"\n");
&print_tempfile(HTACCESS, "AuthType Basic\n");
&print_tempfile(HTACCESS, "AuthName \"$in{'desc'}\"\n");
&print_tempfile(HTACCESS, "require valid-user\n");
&close_tempfile(HTACCESS);
&set_ownership_permissions($d->{'uid'}, $d->{'gid'}, 0755, $file);

# Create users file
&open_lock_tempfile(USERS, ">$usersfile");
&close_tempfile(USERS);
&set_ownership_permissions($d->{'uid'}, $d->{'gid'}, 0750, $usersfile);

# Add to protected dirs list
@dirs = &htaccess_htpasswd::list_directories();
$dirstr = [ $dir, "$usersfile", 0, 0, undef ];
push(@dirs, $dirstr);
&htaccess_htpasswd::save_directories(\@dirs);

&redirect("index.cgi?dom=$in{'dom'}");

