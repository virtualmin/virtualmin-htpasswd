use strict;
use warnings;

do 'virtualmin-htpasswd-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my ($d) = grep { &virtual_server::can_edit_domain($_) }
	       &virtual_server::list_domains();
if ($cgi eq 'add_form.cgi') {
	return $d ? 'dom='.$d->{'id'} : 'none';
	}
return undef;
}
