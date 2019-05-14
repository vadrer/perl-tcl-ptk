# Test of iconimage method. This method is implemented in Tcl as the iconphoto method,
#  which only exists is Tcl/pTk > 8.5
use warnings;
use strict;

use Tcl::pTk;

use Test;
plan tests => 1;

my $top = MainWindow->new();

my $version = $top->tclVersion;
# print "version = $version\n";

# Skip if Tcl/pTk version is < 8.5
if( $version < 8.5 ){
        skip("iconimage only works for Tcl >= 8.5", 1);
        exit;
}


my $icon = $top->Photo(-file =>  Tcl::pTk->findINC("icon.gif"));

$top->iconimage($icon);

$top->idletasks;
MainLoop if (@ARGV);

ok(1);

