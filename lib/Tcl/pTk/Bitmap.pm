package Tcl::pTk::Bitmap;
require Tcl::pTk;
require Tcl::pTk::Image;

use base  qw(Tcl::pTk::Image);
Construct Tcl::pTk::Image 'Bitmap';
sub Tk_image { 'bitmap' }
1;
__END__