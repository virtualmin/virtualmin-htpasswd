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

my $f_apache = $virtual_server::config{'web'};
my $f_indent = "&nbsp;" x 4;
my $f_label;
$f_label = 2 if (!$f_apache);
print &text('find_doing', "<tt>$d->{'home'}</tt>"),"<br>\n";
open(my $FIND, "find ".quotemeta($d->{'home'})." -name ".
	   quotemeta($htaccess_htpasswd::config{'htaccess'}).
	   " -print 2>/dev/null |");
while(my $f = <$FIND>) {
	chop($f);
	my $f_name = $f;
	$f_name =~ s|/[^/]*$|| if (!$f_apache);
	if ($got{$f}) {
		print $f_indent.&text("find_already$f_label", "<tt>$f_name</tt>"),"<br>\n";
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
			my $f_extra;
			if (!$f_apache) {
				# Now add newly found protected directory in other webserver plugins
				my $currfilename = $currfile; # Extract filename from path
				$currfilename =~ s/.*\///;
				foreach my $p (&virtual_server::list_feature_plugins()) {
					my ($err, $status) = &virtual_server::plugin_call($p,
						"feature_add_protected_dir", $d, 
							{ 'protected_dir' => $dir,
							  'protected_user_file_path' => $currfile, 
							  'protected_user_file' => $currfilename,
							  'protected_name' => $text{'find_authreq'} });
					$f_extra = $text{"find_webservstatus$status"} if (defined($status));
					}
				}
			print $f_indent.&text("find_found$f_label", "<tt>$f_name</tt>",
				"<tt>$currfile</tt>")." $f_extra","<br>\n";
			}
		else {
			print $f_indent.&text("find_foundnot$f_label", "<tt>$f_name</tt>"),"<br>\n";
			}
		}
	else {
		print $f_indent.&text("find_noprot$f_label", "<tt>$f_name</tt>"),"<br>\n";
		}
	}
close($FIND);
print $text{'find_founddone'},"<br>\n";
&lock_file($htaccess_htpasswd::directories_file);
&htaccess_htpasswd::save_directories(\@dirs);
&unlock_file($htaccess_htpasswd::directories_file);

&ui_print_footer("index.cgi?dom=$in{'dom'}", $text{'index_return'});
