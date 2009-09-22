#!/usr/local/bin/perl
# Add protection

require './virtualmin-htpasswd-lib.pl';
&ReadParse();
&error_setup($text{'add_err'});

# Validate inputs
$d = &virtual_server::get_domain($in{'dom'});
$d && &virtual_server::can_edit_domain($d) || &error($text{'index_ecannot'});
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
$in{'desc'} =~ /\S/ && $in{'desc'} !~ /["\0\r\n]/ || &error($text{'add_edesc'});

# Check for existing files
$file = "$dir/$htaccess_htpasswd::config{'htaccess'}";
$conf = &apache::get_htaccess_config($file);
foreach $clash ("AuthUserFile", "AuthType", "AuthName") {
	$dirclash = &apache::find_directive($clash, $conf);
	if ($dirclash) {
		&error(&text('add_eclash3', $usersfile, $clash));
		}
	}
$usersfile = "$dir/htusers";
-r $usersfile && &error(&text('add_eclash2', $usersfile));
-l $file && &error(&text('add_esymlink', $file));

# Create .htaccess (as domain owner)
&lock_file($file);
&apache::save_directive("AuthUserFile", [ "\"$usersfile\"" ], $conf, $conf);
&apache::save_directive("AuthType", [ "Basic" ], $conf, $conf);
&apache::save_directive("AuthName", [ "\"$in{'desc'}\"" ], $conf, $conf);
&apache::save_directive("require", [ "valid-user" ], $conf, $conf);
&virtual_server::write_as_domain_user($d,
	sub { &flush_file_lines($file) });
&unlock_file($file);
&virtual_server::set_permissions_as_domain_user($d, 0755, $file);

# Create users file
&lock_file($usersfile);
&virtual_server::open_tempfile_as_domain_user($d, USERS, ">$usersfile");
&virtual_server::close_tempfile_as_domain_user($d, USERS);
$perms = &virtual_server::apache_in_domain_group($d) ? 0750 : 0755;
&virtual_server::set_permissions_as_domain_user($d, $perms, $usersfile);
&unlock_file($usersfile);

# Add to protected dirs list
@dirs = &htaccess_htpasswd::list_directories();
$dirstr = [ $dir, "$usersfile", 0, 0, undef ];
push(@dirs, $dirstr);
&htaccess_htpasswd::save_directories(\@dirs);

&redirect("index.cgi?dom=$in{'dom'}");

