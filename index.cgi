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

# Show table of directories
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   "<a href='add_form.cgi?dom=".&urlize($in{'dom'}).
	    "'>$text{'index_add'}</a>" );
if (@dirs) {
	# Show table of directories
	print &ui_form_start("delete.cgi");
	print &ui_hidden("dom", $in{'dom'}),"\n";
	print &ui_links_row(\@links);
	@tds = ( "width=5", undef, undef, "width=10%" );
	print &ui_columns_start([ "",
				  $text{'index_dir'},
				  $text{'index_desc'},
				  $text{'index_users'} ], undef, 0, \@tds);
	foreach $dir (@dirs) {
		$conf = &apache::get_htaccess_config(
			"$dir->[0]/$htaccess_htpasswd::config{'htaccess'}");
		$desc = &apache::find_directive("AuthName", $conf, 1);
		$users = $dir->[2] == 3 ?
			&htaccess_htpasswd::list_digest_users($dir->[1]) :
			&htaccess_htpasswd::list_users($dir->[1]);
		print &ui_checked_columns_row([
			$d ? &remove_public_html($dir->[0], $d) : $dir->[0],
			$desc,
			scalar(@$users),
			], \@tds, "d", $dir->[0]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

if ($d) {
	&ui_print_footer($d ? &virtual_server::domain_footer_link($d) : ( ),
			 "/virtual-server/",
			 $virtual_server::text{'index_return'});
	}
else {
	&ui_print_footer("/", $text{'index'});
	}

