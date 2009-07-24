#!/usr/local/bin/perl
# Find existing protected directories

require './virtualmin-htpasswd-lib.pl';
&ReadParse();
&error_setup($text{'find_err'});
$in{'dom'} || &error($text{'find_edom'});
$d = &virtual_server::get_domain($in{'dom'});
$d && &virtual_server::can_edit_domain($d) || &error($text{'find_ecannot'});

@dirs = &htaccess_htpasswd::list_directories();
%got = map { ( "$_->[0]/$config{'htaccess'}", 1 ) } @dirs;

# Start the search
&ui_print_header(&virtual_server::domain_in($d), $text{'find_title'}, "");

print &text('find_doing', "<tt>$d->{'home'}</tt>"),"<p>\n";
open(FIND, "find ".quotemeta($d->{'home'})." -name ".
	   quotemeta($htaccess_htpasswd::config{'htaccess'}).
	   " -print 2>/dev/null |");
while($f = <FIND>) {
	chop($f);
	if ($got{$f}) {
		print &text('find_already', "<tt>$f</tt>"),"<br>\n";
		next;
		}

	# Read as the domain user
	&virtual_server::write_as_domain_user($d,
	    sub { 
		$conf = &apache::get_htaccess_config($f);
		$currfile = &apache::find_directive("AuthUserFile", $conf, 1);
		$require = &apache::find_directive("require", $conf, 1);
		});
	if ($currfile && $require) {
		local $dir = $f;
		$dir =~ s/\/$htaccess_htpasswd::config{'htaccess'}$//;
		if (&can_directory($dir, $d)) {
			push(@dirs, [ $dir, $currfile ]);
			print &text('find_found', "<tt>$f</tt>",
				    "<tt>$currfile</tt>"),"<br>\n";
			}
		else {
			print &text('find_foundnot', "<tt>$f</tt>"),"<br>\n";
			}
		}
	else {
		print &text('find_noprot', "<tt>$f</tt>"),"<br>\n";
		}
	}
close(FIND);

&lock_file($htaccess_htpasswd::directories_file);
&htaccess_htpasswd::save_directories(\@dirs);
&unlock_file($htaccess_htpasswd::directories_file);

&ui_print_footer("index.cgi?dom=$in{'dom'}", $text{'index_return'});


