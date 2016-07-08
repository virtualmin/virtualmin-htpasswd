use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'add_form.cgi' );
strict_ok( 'add_form.cgi' );
warnings_ok( 'add_form.cgi' );
