# Defines functions for this feature
use strict;
use warnings;
no warnings 'uninitialized';
our (%text);
our ($module_name, $module_config_directory);

require 'virtualmin-htpasswd-lib.pl';
my $input_name = $module_name;
$input_name =~ s/[^A-Za-z0-9]/_/g;
&load_theme_library();

# feature_name()
# Returns a short name for this feature
sub feature_name
{
return $text{'feat_name'};
}

# feature_check()
# Returns undef if all the needed programs for this feature are installed,
# or an error message if not
sub feature_check
{
return $text{'feat_edep'} if (!&foreign_installed("htaccess-htpasswd", 1));
no warnings "once";
return $text{'feat_eweb'} if (!&virtual_server::domain_has_website());
use warnings "once";
return undef;
}

# mailbox_inputs(&user, new, &domain)
# If any protected directories are defined, returns a list of them for selection
sub mailbox_inputs
{
my ($user, $new, $dom) = @_;

# Find protected directories
my @dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $dom) } @dirs;
return undef if (!@dirs);

# Work out which ones this user has access to
my @indir;
if (!$new) {
	my %indir = &get_in_dirs(\@dirs, $user->{'user'});
	@indir = keys %indir;
	}
else {
	my $lref = &read_file_lines(
		"$module_config_directory/defaults.$dom->{'id'}");
	@indir = @$lref;
	}

no warnings "once";
$main::ui_table_cols = 2;
use warnings "once";
my @opts;
foreach my $dir (@dirs) {
	my $reldir = &remove_public_html($dir->[0], $dom);
	push(@opts, [ $dir->[0], $reldir ]);
	}
my @vals;
foreach my $dir (@indir) {
	my $reldir = &remove_public_html($dir, $dom);
	push(@vals, [ $dir, $reldir ]);
	}
return &ui_table_row(&hlink($text{'user_dirs'}, "dirs"),
	     &ui_multi_select($input_name, \@vals, \@opts,
			      scalar(@dirs) < 3 ? 3 : scalar(@dirs), 0, 0,
			      $text{'user_opts'}, $text{'user_vals'}, 300));
}

# mailbox_validate(&user, &old-user, &in, new, &domain)
# Validates inputs generated by mailbox_inputs, and returns either undef on
# success or an error message
sub mailbox_validate
{
return undef;		# Nothing to do, since any setting is valid
}

# mailbox_save(&user, &old-user, &in, new, &domain)
# Updates the user based on inputs generated by mailbox_inputs
sub mailbox_save
{
my ($user, $old, $in, $new, $dom) = @_;

# Find protected directories
my @dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $dom) } @dirs;
return undef if (!@dirs);
my %indir = $old ? &get_in_dirs(\@dirs, $old->{'user'}) : ( );
my $count = 0;

# Update them all
my %seldir = map { $_, 1 } split(/\r?\n/, $in->{$input_name});
foreach my $d (@dirs) {
	my $suser = $indir{$d->[0]};
	if ($suser && !$seldir{$d->[0]}) {
		# Take out of this directory
		&virtual_server::write_as_domain_user($dom,
			sub { &htaccess_htpasswd::delete_user($suser) });
		}
	elsif (!$suser && $seldir{$d->[0]}) {
		# Add to this directory
		$suser = { 'user' => $user->{'user'},
			   'dom' => $dom->{'dom'},
			   'enabled' => 1 };
		if ($user->{'pass_crypt'}) {
			# Use stored hashed password
			$suser->{'pass'} = $user->{'pass_unix'} ||
			                   $user->{'pass_md5'} ||
			                   $user->{'pass_crypt'};
			}
		elsif ($user->{'passmode'} == 3 ||
		       defined($user->{'plainpass'})) {
			# Re-hashed plaintext password
			$suser->{'pass'} = &htaccess_htpasswd::encrypt_password(
				$user->{'plainpass'}, undef, $d->[2]);
			}
		else {
			# Use MD5 hashed password
			$suser->{'pass'} = $user->{'pass'};
			}
		&virtual_server::write_as_domain_user($dom,
		    sub { &htaccess_htpasswd::create_user($suser, $d->[1]) });
		$count++;
		}
	elsif ($suser && $seldir{$d->[0]}) {
		# Update username and password and domain
		if ($user->{'user'} ne $old->{'user'}) {
			$suser->{'user'} = $user->{'user'};
			}
		if ($user->{'pass'} ne $old->{'pass'}) {
			$suser->{'pass'} = $user->{'pass_unix'} ||
			                   $user->{'pass_md5'} ||
			                   $user->{'pass_crypt'} ||
			    &htaccess_htpasswd::encrypt_password(
				$user->{'plainpass'}, undef, $d->[2]);
			}
		&virtual_server::write_as_domain_user($dom,
			sub { &htaccess_htpasswd::modify_user($suser) });
		$count++;
		}
	}
return $count ? 1 : 0;
}

# mailbox_modify(&user, &old-user, &domain)
# Adds or removes the user from protected directories
sub mailbox_modify
{
my ($user, $old, $dom) = @_;

# Find protected directories
my @dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $dom) } @dirs;
my %indir = $old ? &get_in_dirs(\@dirs, $old->{'user'}) : ( );

# Update the user
foreach my $d (@dirs) {
	my $suser = $indir{$d->[0]};
	if ($suser) {
		if ($user->{'user'} ne $old->{'user'}) {
			$suser->{'user'} = $user->{'user'};
			}
		if ($user->{'pass'} ne $old->{'pass'}) {
			$suser->{'pass'} = $user->{'pass_unix'} ||
			                   $user->{'pass_md5'} ||
			                   $user->{'pass_crypt'} ||
			    &htaccess_htpasswd::encrypt_password(
				$user->{'plainpass'}, undef, $d->[2]);
			}
		&virtual_server::write_as_domain_user($dom,
			sub { &htaccess_htpasswd::modify_user($suser) });
		}
	}
}

# mailbox_delete(&user, &domain)
# Removes any extra features for this user
sub mailbox_delete
{
my ($user, $dom) = @_;

# Find protected directories
my @dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $dom) } @dirs;
my %indir = &get_in_dirs(\@dirs, $user->{'user'});

# Take the user out of them
foreach my $d (@dirs) {
	my $suser = $indir{$d->[0]};
	if ($suser) {
		&virtual_server::write_as_domain_user($dom,
			sub { &htaccess_htpasswd::delete_user($suser) });
		}
	}
}

# mailbox_header(&domain)
# Returns a column header for the user display, or undef for none
sub mailbox_header
{
return undef;
}

# mailbox_column(&user, &domain)
# Returns the text to display in the column for some user
sub mailbox_column
{
return undef;
}

# mailbox_defaults_inputs(&defs, &domain)
# Returns HTML for editing defaults for plugin-related settings for new
# users in this virtual server
sub mailbox_defaults_inputs
{
my ($defs, $dom) = @_;
my $lref =&read_file_lines("$module_config_directory/defaults.$dom->{'id'}");
my @dirs = &htaccess_htpasswd::list_directories();
@dirs = grep { &can_directory($_->[0], $dom) } @dirs;
return undef if (!@dirs);
return &ui_table_row($text{'user_dirs'},
     &ui_select($input_name, $lref,
	[ map { [ $_->[0], &remove_public_html($_->[0], $dom) ] }
	      @dirs ], 3, 1), 3);
}

# mailbox_defaults_parse(&defs, &domain, &in)
# Parses the inputs created by mailbox_defaults_inputs, and updates a config
# file internal to this module to store them
sub mailbox_defaults_parse
{
my ($defs, $dom, $in) = @_;
my $lref =&read_file_lines("$module_config_directory/defaults.$dom->{'id'}");
@$lref = split(/\0/, $in->{$input_name});
&flush_file_lines("$module_config_directory/defaults.$dom->{'id'}");
}

# get_in_dirs(&dirs, username)
# Returns a list of directories some user has access too, as a hash
sub get_in_dirs
{
my ($dirs, $username) = @_;
my %indir;
foreach my $d (@$dirs) {
	my $users = $d->[2] == 3 ?
		&htaccess_htpasswd::list_digest_users($d->[1]) :
		&htaccess_htpasswd::list_users($d->[1]);
	my ($got) = grep { $_->{'user'} eq $username } @$users;
	$indir{$d->[0]} = $got if ($got);
	}
return %indir;
}

# feature_always_links(&domain)
# Returns an array of link objects for webmin modules for this plugin
sub feature_always_links
{
my ($d) = @_;
if (&virtual_server::domain_has_website($d) && $d->{'dir'} && !$d->{'alias'}) {
	return ( { 'mod' => $module_name,
		   'desc' => $text{'links_link'},
		   'page' => 'index.cgi?dom='.$d->{'id'},
		   'cat' => 'services',
		 } );
	}
}

# Grant this Webmin module only for domain owners who have some web domains
sub feature_webmin
{
my @doms = grep { $_->{'web'} && $_->{'dir'} && !$_->{'alias'} } @{$_[1]};
if (@doms) {
	return ( [ $module_name ] );
	}
else {
	return ( );
	}
}

1;
