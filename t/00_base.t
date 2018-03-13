use 5.012;
use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok( 'Mira' ) || print "Bail out!\n";
}

diag( "Testing Mira $Mira::VERSION, Perl $], $^X" );
