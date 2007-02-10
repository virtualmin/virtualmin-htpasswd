#!/usr/local/bin/perl
# Show a form for adding protection to a directory

require './virtualmin-htpasswd-lib.pl';
&ReadParse();
if ($in{'dom'}) {
	$d = &virtual_server::get_domain($in{'dom'});
	&virtual_server::can_edit_domain($d) || &error($text{'index_ecannot'});
	}

&ui_print_header($d ? &virtual_server::domain_in($d) : undef,
		 $text{'add_title'}, "");

print &ui_form_start("add.cgi", "post");
print &ui_table_start($text{'add_header'}, undef, 2);

# Domain selector
if (!$d) {
	@doms = grep { &virtual_server::can_edit_domain($_) } 
		     &virtual_server::list_domains();
	print &ui_table_row($text{'add_dom'},
	    &ui_select("dom", undef,
		       [ map { [ $_->{'id'}, $_->{'dom'} ] } @doms ]));
	}
else {
	print &ui_hidden("dom", $in{'dom'}),"\n";
	}

# Directory under public_html
print &ui_table_row($text{'add_dir'},
	&ui_opt_textbox("dir", undef, 30, $text{'add_all'}));

# Authentication realm
print &ui_table_row($text{'add_desc'},
	&ui_textbox("desc", undef, 40));

print &ui_table_end();
print &ui_form_end([ [ "create", $text{'create'} ] ]);

&ui_print_footer("index.cgi?dom=$in{'dom'}", $text{'index_return'});

