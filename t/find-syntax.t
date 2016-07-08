use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'find.cgi' );
strict_ok( 'find.cgi' );
warnings_ok( 'find.cgi' );
