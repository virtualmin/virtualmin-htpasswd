use strict;
use warnings;
our ($module_name, %gconfig);

do 'virtualmin-htpasswd-lib.pl';

sub module_install
{
# Enable virtualmin-htpasswd module once
my %vconfig = &foreign_config("virtual-server");
my @p = split(/\s+/, $vconfig{'plugins'} || '');
my @ppe = split(/\s+/, $vconfig{'plugins_postinstall_enabled'} || '');
if (&indexof('virtualmin-nginx', @p) >= 0 &&
    &indexof($module_name, @p) < 0 &&
    &indexof($module_name, @ppe) < 0) {
	&virtual_server::lock_file($virtual_server::module_config_file);
	push(@p, $module_name);
	push(@ppe, $module_name);
	$vconfig{'plugins'} = join(" ", @p);
	$vconfig{'plugins_postinstall_enabled'} = join(" ", @ppe);
	&virtual_server::save_module_config(\%vconfig, 'virtual-server');
	&virtual_server::unlock_file($virtual_server::module_config_file);
	}
}
