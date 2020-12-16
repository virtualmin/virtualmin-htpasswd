#!/usr/local/bin/perl
# Find existing protected directories
use strict;
use warnings;
our (%text, %in);

require './virtualmin-htpasswd-lib.pl';
&ReadParse();
&error_setup($text{'find_err'});
$in{'dom'} || &error($text{'find_edom'});
my $d = &virtual_server::get_domain($in{'dom'});
$d && &virtual_server::can_edit_domain($d) || &error($text{'find_ecannot'});

my @dirs = &htaccess_htpasswd::list_directories();
my %got = map { ( "$_->[0]/$htaccess_htpasswd::config{'htaccess'}", 1 ) } @dirs;

# Start the search
&ui_print_header(&virtual_server::domain_in($d), $text{'find_title'}, "");

print &text('find_doing', "<tt>$d->{'home'}</tt>"),"<p>\n";
open(my $FIND, "find ".quotemeta($d->{'home'})." -name ".
	   quotemeta($htaccess_htpasswd::config{'htaccess'}).
	   " -print 2>/dev/null |");
while(my $f = <$FIND>) {
	chop($f);
	if ($got{$f}) {
		print &text('find_already', "<tt>$f</tt>"),"<br>\n";
		next;
		}

	# Read as the domain user
	my ($conf, $currfile, $require);
	&virtual_server::write_as_domain_user($d,
	  sub {
			$conf = &apache::get_htaccess_config($f);
			$currfile = &apache::find_directive("AuthUserFile", $conf, 1);
		$require = &apache::find_directive("require", $conf, 1);
		});
	if ($currfile && $require) {
		my $dir = $f;
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
close($FIND);

&lock_file($htaccess_htpasswd::directories_file);
&htaccess_htpasswd::save_directories(\@dirs);
&unlock_file($htaccess_htpasswd::directories_file);

&ui_print_footer("index.cgi?dom=$in{'dom'}", $text{'index_return'});
