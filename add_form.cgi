#!/usr/local/bin/perl
# Show a form for adding protection to a directory
use strict;
use warnings;
our (%in, %text);

require './virtualmin-htpasswd-lib.pl';
&ReadParse();
my $d;
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
	my @doms = grep { &virtual_server::can_edit_domain($_) }
		     &virtual_server::list_domains();
	print &ui_table_row($text{'add_dom'},
	    &ui_select("dom", undef,
		       [ map { [ $_->{'id'}, $_->{'dom'} ] } @doms ]));
	}
else {
	print &ui_hidden("dom", $in{'dom'}),"\n";
	}

# Directory under public_html
print &ui_table_row(&hlink($text{'add_dir'}, 'add_dir'),
	&ui_radio_table("dir_def", 1,
		[ [ 1, $text{'add_all'} ],
		  [ 0, $text{'add_subdir'}, &ui_textbox("dir", undef, 30) ],
		  [ 2, $text{'add_subcgi'}, &ui_textbox("cgi", undef, 30) ] ]));

# Authentication realm
print &ui_table_row(&hlink($text{'add_desc'}, 'add_desc'),
	&ui_textbox("desc", undef, 40));

print &ui_table_end();
print &ui_form_end([ [ "create", $text{'create'} ] ]);

&ui_print_footer("index.cgi?dom=$in{'dom'}", $text{'index_return'});
