#!/usr/local/bin/perl
# Remove protection for several directories
use strict;
use warnings;
our (%text, %in);

require './virtualmin-htpasswd-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});

# Validate inputs
my @d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});
my $d;
if ($in{'dom'}) {
	$d = &virtual_server::get_domain($in{'dom'});
	&virtual_server::can_edit_domain($d) || &error($text{'index_ecannot'});
	}

my @dirs = &htaccess_htpasswd::list_directories();
my $htusers = $htaccess_htpasswd::config{'htpasswd'} || "htusers";
foreach my $path (@d) {
	&can_directory($path, $d) || &error($text{'delete_ecannot'});
	my ($dir) = grep { $_->[0] eq $path } @dirs;
	if ($dir) {
		# Delete protected directory in other webserver plugins
		foreach my $p (&virtual_server::list_feature_plugins()) {
			my $err = &virtual_server::plugin_call($p,
				"feature_delete_protected_dir", $d,
					{ 'protected_dir' => $dir->[0],
					  'protected_user_file_path' => $dir->[1] });
			&error($err) if ($err);
			}
		# Remove protection directives
		no warnings "once";
		my $file = "$dir->[0]/$htaccess_htpasswd::config{'htaccess'}";
		&lock_file($file);
		my $conf = &apache::get_htaccess_config($file);
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
		use warnings "once";

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
