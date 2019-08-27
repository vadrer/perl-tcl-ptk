use warnings;
use strict;

use Tcl::pTk;
#use Tk;

use Test;

plan test => 4;

my $mw = MainWindow->new;
#my $mw_f = $mw->Frame(-height => 200, -width => 200)->pack;

my $t = $mw->Toplevel;
#my $t_f = $t->Frame(-height => 200, -width => 200)->pack;

$mw->idletasks;
$mw->lower($t);
ok($t->stackorder('isabove', $mw), 0, '[wm stackorder $t isabove $mw] == 0');
ok($t->stackorder('isbelow', $mw), 1, '[wm stackorder $t isbelow $mw] == 1');
ok($mw->stackorder('isabove', $t), 1, '[wm stackorder $mw isabove $t] == 1');
ok($mw->stackorder('isbelow', $t), 0, '[wm stackorder $mw isbelow $t] == 0');

MainLoop if (@ARGV);
