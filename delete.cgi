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
		&unlink_logged(
			"$dir->[0]/$htaccess_htpasswd::config{'htaccess'}");
		if (&can_directory($dir->[1], $d)) {
			&unlink_logged($dir->[1]);
			}
		}
	}

&redirect("index.cgi?dom=$in{'dom'}");

