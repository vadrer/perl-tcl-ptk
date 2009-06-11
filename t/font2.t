#!/usr/local/bin/perl -w

# Script to check that font create methods return font objects
#   

use Tcl::Tk qw/:perlTk/;
#use Tk;
use Test;

plan test => 2;

use Data::Dumper;

$| = 1; # Pipes Hot
my $top = MainWindow->new;
        
my $font = $top->fontCreate('courier', -family => 'courier', -size => 10);
 
ok( ref($font) , 'Tcl::Tk::Font', "fontCreate returns object");
#print "font is a ".ref($font)."\n";


my $font2 = $top->Font(-family => 'courier', -size => 10);
#print "font2 is a ".ref($font)."\n";
ok( ref($font) , 'Tcl::Tk::Font', "fontCreate returns object");


#MainLoop;


        
