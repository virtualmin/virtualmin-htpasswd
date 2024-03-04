use strict;
use warnings;
our ($module_name, %gconfig);

do 'virtualmin-htpasswd-lib.pl';

sub module_install
{
# Enable virtualmin-htpasswd module once
if (&virtual_server::plugin_defined("virtualmin-nginx", "start_nginx")) {
    if ($virtual_server::config{'plugins'} !~ /$module_name/ &&
        $virtual_server::config{'plugins_postinstall_enabled'} !~ /$module_name/) {
        &virtual_server::lock_file($virtual_server::module_config_file);
        $virtual_server::config{'plugins'} .= " $module_name";
        $virtual_server::config{'plugins'} =~ s/^\s+|\s+$//g;
        $virtual_server::config{'plugins_postinstall_enabled'} .= " $module_name";
        $virtual_server::config{'plugins_postinstall_enabled'} =~ s/^\s+|\s+$//g;
        &virtual_server::save_module_config(\%virtual_server::config, 'virtual-server');
        &virtual_server::unlock_file($virtual_server::module_config_file);
        }
	}
}

