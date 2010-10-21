#!/usr/local/bin/perl
# Remove protection for several directories

require './virtualmin-htpasswd-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});

# Validate inputs
@d = split(/\s+/, $in{'d'});
@d || &error($text{'delete_enone'});
if ($in{'dom'}) {
	$d = &virtual_server::get_domain($in{'dom'});
	&virtual_server::can_edit_domain($d) || &error($text{'index_ecannot'});
	}

@dirs = &htaccess_htpasswd::list_directories();
foreach $path (@d) {
	&can_directory($path, $d) || &error($text{'delete_ecannot'});
	($dir) = grep { $_->[0] eq $path } @dirs;
	if ($dir) {
		# Remove protection directives
		$file = "$dir->[0]/$htaccess_htpasswd::config{'htaccess'}";
		&lock_file($file);
		$conf = &apache::get_htaccess_config($file);
		&apache::save_directive("AuthUserFile", [ ], $conf, $conf);
		&apache::save_directive("AuthType", [ ], $conf, $conf);
		&apache::save_directive("AuthName", [ ], $conf, $conf);
		&apache::save_directive("require", [ ], $conf, $conf);
		if ($main::file_cache{$file}) {
			&virtual_server::write_as_domain_user($d,
				sub { &flush_file_lines($file) });
			}

		# Remove whole file if empty
		if (&empty_file($file)) {
			&virtual_server::unlink_logged_as_domain_user(
				$d, $file);
			}
		&unlock_file($file);

		# Remove htusers file
		if (&can_directory($dir->[1], $d)) {
			&virtual_server::unlink_logged_as_domain_user(
				$d, $dir->[1]);
			}
		@dirs = grep { $_ ne $dir } @dirs;
		}
	}
&htaccess_htpasswd::save_directories(\@dirs);

&redirect("index.cgi?dom=$in{'dom'}");

