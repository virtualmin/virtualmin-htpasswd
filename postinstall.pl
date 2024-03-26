use strict;
use warnings;
our ($module_name, %gconfig);

do 'virtualmin-htpasswd-lib.pl';

sub module_install
{
# Enable virtualmin-htpasswd module once
my @p = split(/\s+/, $virtual_server::config{'plugins'});
my @ppe = split(/\s+/, $virtual_server::config{'plugins_postinstall_enabled'} // '');
if (&indexof('virtualmin-nginx', @virtual_server::plugins) > -1 &&
    &indexof($module_name, @p) == -1 &&
    &indexof($module_name, @ppe) == -1) {
	&virtual_server::lock_file($virtual_server::module_config_file);
	push(@p, $module_name);
	push(@ppe, $module_name);
	$virtual_server::config{'plugins'} = join(" ", @p);
	$virtual_server::config{'plugins_postinstall_enabled'} = join(" ", @ppe);
	&virtual_server::save_module_config(\%virtual_server::config, 'virtual-server');
	&virtual_server::unlock_file($virtual_server::module_config_file);
	}
}

