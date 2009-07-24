#!/usr/local/bin/perl
# Show directories for which web protection is enabled, with a form
# to add a new one. For Virtualmin domain owners, the list is limited to
# a single domain.

require './virtualmin-htpasswd-lib.pl';
&ReadParse();
&foreign_require("apache", "apache-lib.pl");

# Get domain and directories
if ($in{'dom'}) {
	$d = &virtual_server::get_domain($in{'dom'});
	&virtual_server::can_edit_domain($d) || &error($text{'index_ecannot'});
	}
@dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $d) } @dirs;

&ui_print_header($d ? &virtual_server::domain_in($d) : undef,
		 $text{'index_title'}, "", "intro", 0, 1);

# Build table of directories
@table = ( );
foreach $dir (@dirs) {
	$conf = &apache::get_htaccess_config(
		"$dir->[0]/$htaccess_htpasswd::config{'htaccess'}");
	$desc = &apache::find_directive("AuthName", $conf, 1);
	$users = $dir->[2] == 3 ?
		&htaccess_htpasswd::list_digest_users($dir->[1]) :
		&htaccess_htpasswd::list_users($dir->[1]);
	push(@table, [
		{ 'type' => 'checkbox', 'name' => 'd', 'value' => $dir->[0] },
		$d ? &remove_public_html($dir->[0], $d) : $dir->[0],
		$desc,
		scalar(@$users),
		]);
	}

# Render table of directories
print &ui_form_columns_table(
	"delete.cgi",
	[ [ "delete", $text{'index_delete'} ] ],
	1,
	[ [ "add_form.cgi?dom=".&urlize($in{'dom'}), $text{'index_add'} ] ],
	[ [ "dom", $in{'dom'} ] ],
	[ "", $text{'index_dir'}, $text{'index_desc'}, $text{'index_users'} ],
	undef,
	\@table,
	undef,
	0,
	undef,
	$text{'index_none'});

# Show button to find more
if ($d) {
	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("find.cgi", $text{'index_find'},
			      &text('index_finddesc', "<tt>$d->{'home'}</tt>"),
			      &ui_hidden("dom", $in{'dom'}));
	print &ui_buttons_end();
	}

if ($d) {
	&ui_print_footer($d ? &virtual_server::domain_footer_link($d) : ( ),
			 "/virtual-server/",
			 $virtual_server::text{'index_return'});
	}
else {
	&ui_print_footer("/", $text{'index'});
	}

