package Tcl::Tk;

use strict;
use Tcl;
use Exporter ('import');
use Scalar::Util (qw /blessed/); # Used only for it's blessed function
use vars qw(@EXPORT_OK %EXPORT_TAGS $platform @cleanup_refs $cleanup_queue_maxsize $cleanupPending);

# Wait till we have 100 things to delete before we do cleanup
$cleanup_queue_maxsize = 50;

# Set the platform global variable, based on the OS we are running under
BEGIN{ 
 if($^O eq 'cygwin')
  {
   $platform = 'MSWin32'
  }
 else
  {
   $platform = ($^O eq 'MSWin32') ? $^O : 'unix';
  }
};


use Tcl::Tk::Widget;
use Tcl::Tk::Widget::MainWindow;
use Tcl::Tk::Widget::DialogBox;
use Tcl::Tk::Widget::Dialog;
use Tcl::Tk::Widget::LabEntry;
use Tcl::Tk::Widget::ROText;
use Tcl::Tk::Widget::Listbox;
use Tcl::Tk::Widget::Balloon;
use Tcl::Tk::Widget::Menu;
use Tcl::Tk::Widget::Menubutton;
use Tcl::Tk::Widget::Canvas;
use Tcl::Tk::Font;


# Tcl::Tk::libary variable: Translation from perl/tk Tk.pm
{($Tcl::Tk::library) = __FILE__ =~ /^(.*)\.pm$/;}
$Tcl::Tk::library = Tk->findINC('.') unless (defined($Tcl::Tk::library) && -d $Tcl::Tk::library);


# Global vars used by this package

our ( %W, $Wint, $Wpath, $Wdata, $DEBUG );


# For debugging, we use Sub::Name to name anonymous subs, this makes tracing the program
#   much easier (using perl -d:DProf or other tools)
$DEBUG =1;
if($DEBUG){
        require Sub::Name;
        import Sub::Name;
}


@Tcl::Tk::ISA = qw(Tcl);
$Tcl::Tk::VERSION = '0.97';

sub WIDGET_CLEANUP() {1}

$Tcl::Tk::DEBUG ||= 0;
sub DEBUG() {0}
sub _DEBUG {
    # Allow for optional debug level and message to be passed in.
    # If level is passed in, return true only if debugging is at
    # that level.
    # If message is passed in, output that message if the level
    # is appropriate (with any extra args passed to output).
    my $lvl = shift;
    return $Tcl::Tk::DEBUG unless defined $lvl;
    my $msg = shift;
    if (defined($msg) && ($Tcl::Tk::DEBUG >= $lvl)) { print STDERR $msg, @_; }
    return ($Tcl::Tk::DEBUG >= $lvl);
}

if (DEBUG()) {
    # The gestapo throws warnings whenever Perl/Tk modules are requested.
    # It also hijacks such requests and returns an empty module in its
    # place.
    unshift @INC, \&tk_gestapo;
}

=head1 NAME

Tcl::Tk - Extension module for Perl giving access to Tk via the Tcl extension

=head1 SYNOPSIS

    use Tcl::Tk;
    my $int = new Tcl::Tk;
    my $mw = $int->mainwindow;
    my $lab = $mw->Label(-text => "Hello world")->pack;
    my $btn = $mw->Button(-text => "test", -command => sub {
        $lab->configure(-text=>"[". $lab->cget('-text')."]");
    })->pack;
    $int->MainLoop;

Or    

    use Tcl::Tk;
    my $int = new Tcl::Tk;
    $int->Eval(<<'EOS');
    # pure-tcl code to create widgets (e.g. generated by some GUI builder)
    entry .e
    button .inc -text {increment by Perl}
    pack .e .inc
    EOS
    my $btn = $int->widget('.inc'); # get .inc button into play
    my $e = $int->widget('.e');     # get .e entry into play
    $e->configure(-textvariable=>\(my $var='aaa'));
    $btn->configure(-command=>sub{$var++});
    $int->MainLoop;

=head1 DESCRIPTION

The C<Tcl::Tk> module provides access to the Tk library within Tcl/Tk
installation. By using this module an interpreter object created, which
then gain access to entire variety of installed Tcl libraries (Tk, Tix,
BWidgets, BLT, etc) and existing features (for example natively looking
widgets using C<tile>).

=head2 Access to the Tcl and Tcl::Tk extensions

To get access to the Tcl and Tcl::Tk extensions, put the command near
the top of your program.

    use Tcl::Tk;

=head2 Creating a Tcl interpreter for Tk

Before you start using widgets, an interpreter (at least one) should be
created, which will manage all things in Tcl.

To create a Tcl interpreter initialised for Tk, use

    my $int = new Tcl::Tk;

Optionally DISPLAY argument could be specified: C<my $int = new Tcl::Tk(":5");>.
This creates a Tcl interpreter object $int, and creates a main toplevel
window. The window is created on display DISPLAY (defaulting to the display
named in the DISPLAY environment variable)

The Tcl/Tk interpreter is created automatically by the call to C<MainWindow> and
C<tkinit> methods, and main window object is returned in this case:

  use Tcl::Tk;
  my $mw = Tcl::Tk::MainWindow;
  my $int = $mw->interp;

=head2 Entering the main event loop

The Perl method call

    $int->MainLoop;

on the Tcl::Tk interpreter object enters the Tk event loop. You can
instead do C<Tcl::Tk::MainLoop> or C<Tcl::Tk-E<gt>MainLoop> if you prefer.
You can even do simply C<MainLoop> if you import it from Tcl::Tk in
the C<use> statement.

=head2 Creating and using widgets

Two different approaches are used to manipulate widgets (or, more commonly,
to manipulate any Tcl objects behaving similarly)

=over

=item * access with a special widget accessing syntax of kind C<< $widget->method; >>

=item * random access with C<< Eval >>

=back

First way to manipulate widgets is identical to perl/Tk calling conventions,
second one deploys Tcl syntax. Both ways are very interchangeable in that
sence, a widget created with one way could be used by another way.

Usually Perl programs operate with Tcl/Tk via perl/Tk syntax, so user have no
need to deal with Tcl language directly, only some basic understanding of
widget is needed.

A possibility to use both approaches interchangeably gives an opportunity to
use Tcl code created elsewhere (some WYSIWIG IDE or such).

In order to get better understanding on usage of Tcl/Tk widgets from within
Perl, a bit of Tcl/Tk knowledge is needed, so we'll start from 2nd approach,
with Tcl's Eval (C<< $int->Eval('...') >>) and then smoothly move to 1st,
approach with perl/Tk syntax.

=head4 Tcl/Tk syntax

=over

=item * interpreter

Tcl interpreter is used to process Tcl/Tk widgets; within C<Tcl::Tk> you
create it with C<new>, and, given any widget object, you can retreive it by
C<< $widget->interp >> method. Within pure Tcl/Tk it is already exist.

=item * widget path

Widget path is a string starting with a dot and consisting of several
names separated by dots. These names are widget names that comprise
widget's hierarchy. As an example, if there exists a frame with a path
C<.fram> and you want to create a button on it and name it C<butt> then
you should specify name C<.fram.butt>. Widget paths are refered in
miscellaneous widget operations, and geometry management is one of them.

At any time widget's path could be retreived with C<< $widget->path; >>
within C<Tcl::Tk>.

=item * widget as Tcl/Tk command

when widget is created, a special command is created within Tk, the name of
this command is widget's path. That said, C<.fr.b> is Tk's command and this
command has subcommands, those will help manipulating widget. That is why
C<< $int->Eval('.fr.b configure -text {new text}'); >> makes sence.
Note that C<< $button->configure(-text=>'new text'); >> does exactly that,
provided a fact C<$button> corresponds to C<.fr.b> widget.

=back

C<use Tcl::Tk;> not only creates C<Tcl::Tk> package, but also it creates
C<Tcl::Tk::Widget> package, responsible for widgets. Each widget (object
blessed to C<Tcl::Tk::Widget>, or other widgets in ISA-relationship)
behaves in such a way that its method will result in calling it's path on
interpreter.

=head4 Perl/Tk syntax

C<Tcl::Tk::Widget> package within C<Tcl::Tk> module fully aware of perl/Tk
widget syntax, which has long usage. This means that any C<Tcl::Tk> widget
has a number of methods like C<Button>, C<Frame>, C<Text>, C<Canvas> and so
on, and invoking those methods will create appropriate child widget.
C<Tcl::Tk> module will generate an unique name of newly created widget.

To demonstrate this concept:

    my $label = $frame->Label(-text => "Hello world");

executes the command

    $int->call("label", ".l", "-text", "Hello world");

and this command similar to

    $int->Eval("label .l -text {Hello world}");

This way Tcl::Tk widget commands are translated to Tcl syntax and directed to
Tcl interpreter; understanding this helps in idea, why two approaches with
dealing with widgets are interchangeable.

Newly created widget C<$label> will be blessed to package C<Tcl::Tk::Widget::Label>
which is isa-C<Tcl::Tk::Widget>

=head3 OO explanations of Widget-s of Tcl::Tk

C<Tcl::Tk> widgets use object-oriented approach, which means a quite concrete
object hierarchy presents. Interesting point about this object system - 
it is very dynamic. Initially no widgets objects and no widget classes present,
but they immediately appear at the time when they needed.

So they virtually exist, but come into actual existance dynamically. This
dynamic approach allows same usage of widget library without any mention from
within C<Tcl::Tk> module at all.

Let us look into following few lines of code:

  my $text = $mw->Text->pack;
  $text->insert('end', -text=>'text');
  $text->windowCreate('end', -window=>$text->Label(-text=>'text of label'));

Internally, following mechanics comes into play.
Text method creates Text widget (known as C<text> in Tcl/Tk environment). 
When this creation method invoked first time, a package 
C<Tcl::Tk::Widget::Text> is created, which will be OO presentation of all
further Text-s widgets. All such widgets will be blessed to that package
and will be in ISA-relationship with C<Tcl::Tk::Widget>.

Second line calls method C<insert> of C<$text> object of type
C<Tcl::Tk::Widget::Text>. When invoked first time, a method C<insert> is 
created in package C<Tcl::Tk::Widget::Text>, with destiny to call
C<invoke> method of our widget in Tcl/Tk world.

At first time when C<insert> is called, this method does not exist, so AUTOLOAD
comes to play and creates such a method. Second time C<insert> called already
existing subroutine will be invoked, thus saving execution time.

As long as widgets of different type 'live' in different packages, they do not
intermix, so C<insert> method of C<Tcl::Tk::Widget::Listbox> will mean
completely different behaviour.

=head3 explanations how Widget-s of Tcl::Tk methods correspond to Tcl/Tk

Suppose C<$widget> isa-C<Tcl::Tk::Widget>, its path is C<.path> and method
C<method> invoked on it with a list of parameters, C<@parameters>:

  $widget->method(@parameters);

In this case as a first step all C<@parameters> will be preprocessed, during
this preprocessing following actions are performed:

=over

=item 1.

for each variable reference its Tcl variable will be created and tied to it

=item 2.

for each code reference its Tcl command will be created and tied to it

=item 3.

each array reference considered as callback, and proper actions will be taken

=back

After adoptation of C<@parameters> Tcl/Tk interpreter will be requested to
perform following operation:

=over

=item if C<$method> is all lowercase, C<m/^[a-z]$/>

C<.path method parameter1 parameter2> I<....>

=item if C<$method> contains exactly one capital letter inside name, C<m/^[a-z]+[A-Z][a-z]+$/>

C<.path method submethod parameter1 parameter2> I<....>

=item if C<$method> contains several capital letter inside name, C<methodSubmethSubsubmeth>

C<.path method submeth subsubmeth parameter1 parameter2> I<....>

=head4 faster way of invoking methods on widgets

In case it is guaranteed that preprocessing of C<@parameters> are not required
(in case no parameters are Perl references to scalar, subroutine or array), then
preprocessing step described above could be skipped.

To achieve that, prepend method name with underscore, C<_>. Mnemonically it means
you are using some internal method that executes faster, but normally you use
"public" method, which includes all preprocessing.

Example:

   # at following line faster method is incorrect, as \$var must be
   # preprocessed for Tcl/Tk:
   $button->configure(-textvariable=>\$var);

   # faster version of insert method of "Text" widget is perfectly possible
   $text->_insert('end','text to insert','tag');
   # following line does exactly same thing as previous line:
   $text->_insertEnd('text to insert','tag');

When doing many inserts to text widget, faster version could fasten execution.

=back

=head2 using any Tcl/Tk feature with Tcl::Tk module

Tcl::Tk module allows using any widget from Tcl/Tk widget library with either
Tcl syntax (via Eval), or with regular Perl syntax.

In order to provide perlTk syntax to any Tcl/Tk widget, only single call
should be made, namely 'Declare' method. This is a method of any widget in
Tcl::Tk::Widget package, and also exactly the same method of Tcl::Tk
interpreter object

Syntax is

 $widget->Declare('perlTk_widget_method_name','tcl/tk-widget_method_name',
    @options);

or, exactly the same,
 
 $interp->Declare('perlTk_widget_method_name','tcl/tk-widget_method_name',
    @options);
 
Options are:

  -require => 'tcl-package-name'
  -prefix => 'some-prefix'

'-require' option specifies that said widget requires a Tcl package with a name
of 'tcl-package-name';
'-prefix' option used to specify a part of autogenerated widget name, usually
used when Tcl widget name contain non-alphabet characters (e.g. ':') so
to keep autogenerated names syntaxically correct.

A typical example of such invocation is:

  $mw->Declare('BLTNoteBook','blt::tabnotebook',-require=>'BLT',-prefix=>'bltnbook');

After such a call Tcl::Tk module will take a knowledge about tabnotebook widget
from within BLT package and create proper widget creation method for it with a 
name BLTNoteBook. This means following statement:

 my $tab = $mw->BLTNoteBook;

will create blt::tabnotebook widget. Effectively, this is similar to following
Tcl/Tk code:

  package require BLT # but invoked only once
  blt::tabnotebook .bltnbook1

Also, Perl variable $tab will contain ordinary Tcl/Tk widget that behaves in
usual way, for example:

  $tab->insert('end', -text=>'text');
  $tab->tabConfigure(0, -window=>$tab->Label(-text=>'text of label'));

These two lines are Tcl/Tk equivalent of:

  .bltnbook1 insert end -text {text}
  .bltnbook1 tab configure 0 -window [label .bltnbook1.lab1 -text {text of label}]

Given all previously said, you can also write intermixing both approaches:

  $interp->Eval('package require BLT;blt::tabnotebook .bltnbook1');
  $tab = $interp->widget('.bltnbook1');
  $tab->tabConfigure(0, -window=>$tab->Label(-text=>'text of label'));

=head3 using documentation of Tcl/Tk widgets for applying within Tcl::Tk module

As a general rule, you need to consult TCL man pages to realize how to
use a widget, and after that invoke perl command that creates it properly.
When reading Tcl/Tk documentation about widgets, quite simple transformation is
needed to apply to Tcl::Tk module.

Suppose it says:

  pathName method-name optional-parameters
     (some description)
     
you should understand, that widget in question has method C<method-name> and you could
invoke it as

  $widget->method-name(optional-parameters);

$widget is that widget with pathName, created with perl/Tk syntax, or fetched by
C<< $int->widget >> method.

Sometimes in Tcl/Tk method-name consist of two words (verb1 verb2), in this
case there are two ways to invoke it, C<< $widget->verb1('verb2',...); >> or it
C<< $widget->verb1Verb2(...); >> - those are identical.

Widget options are same within Tcl::Tk and Tcl/Tk.

=head3 C<< $int->widget( path, widget-type ) >> method

When widgets are created they are stored internally and could be retreived
by C<widget()>, which takes widget path as first parameter, and optionally
widget type (such as Button, or Text etc.). Example:

    # this will retrieve widget, and then call configure on it
    widget(".fram.butt")->configure(-text=>"new text");

    # this will retrieve widget as Button (Tcl::Tk::Widget::Button object)
    my $button = widget(".fram.butt", 'Button');
    
    # same but retrieved widget considered as general widget, without
    # concrete specifying its type (Tcl::Tk::Widget object)
    my $button = widget(".fram.butt");

Please note that this method will return to you a widget object even if it was
not created within this module, and check will not be performed whether a 
widget with given path exists, despite of fact that checking for existence of
a widget is an easy task (invoking C<< $interp->Eval("info commands $path"); >>
will do this). Instead, you will receive perl object that will try to operate
with widget that has given path even if such path do not exists. In case it do
not actually exist, you will receive an error from Tcl/Tk.

To check if a widget with a given path exists use C<Tcl::Tk::Exists($widget)>
subroutine. It queries Tcl/Tk for existance of said widget.

=head3 C<widget_data> method

If you need to associate any data with particular widget, you can do this with 
C<widget_data> method of either interpreter or widget object itself. This method
returns same anonymous hash and it should be used to hold any keys/values pairs.

Examples:

  $interp->widget_data('.fram1.label2')->{var} = 'value';
  $label->widget_data()->{var} = 'value';

=head2 Non-widget Tk commands

Many non-widget Tk commands are also available within Tcl::Tk module, such
as C<focus>, C<wm>, C<winfo> and so on. If some of them not present directly,
you can always use C<< $int->Eval('...') >> approach.

=head2 Miscellaneous methods

=head3 C<< $widget->tooltip("text") >> method

Any widget accepts C<tooltip> method, accepting any text as parameter, which
will be used as floating help text explaining the widget. The widget itself
is returned, so to provide convenient way of chaining:

  $mw->Button(-text=>"button 1")->tooltip("This is a button, m-kay")->pack;
  $mw->Entry(-textvariable=>\my $e)->tooltip("enter the text here, m-kay")->pack;

C<tooltip> method uses C<tooltip> package, which is a part of C<tklib> within
Tcl/Tk, so be sure you have it installed.

  
=head1 Points of special care

=over

=item list context and scalar context

When widget method returns some result, this result becomes transformed
according to the context, either list or scalar context. Sometimes this
transformation is right, but sometimes its not. Unfortunately there are many
cases, when Tcl/Tk returns a string, and this string become broken into words,
because the function call is placed in list context.

In such cases concatenate such call with empty string to force right behaviour:

  use Tcl::Tk;
  my $mw = Tcl::Tk::tkinit;
  my $int = $mw->interp;
  my $but = $mw->Button(-text=>'1 2  3')->pack;
  print "[", $but->cget('-text'), "] wrong - widget method returns 3 values!\n";
  print "[", "".$but->cget('-text'), "] CORRECT - 1 value in scalar context\n";
  $int->MainLoop;

Actually, the example above will work correctly, because currently list of
function names having list results are maintained. But please contact developers
if you find misbehaving widget method!

=back

=head1 BUGS

Currently work is in progress, and some features could change in future
versions.

=head1 AUTHORS

=over

=item Malcolm Beattie.

=item Vadim Konovalov, vadim_tcltk@vkonovalov.ru 19 May 2003.

=item Jeff Hobbs, jeffh _a_ activestate com, February 2004.

=item Gisle Aas, gisle _a_ activestate . com, 14 Apr 2004.

=back

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut

my @misc = qw(MainLoop after destroy focus grab lower option place raise
              image font
	      selection tk grid tkwait update winfo wm);
my @perlTk = qw(MainWindow MainLoop DoOneEvent tkinit update Ev Exists);

# Flags for supplying to DoOneEvent
my @eventFlags = qw(DONT_WAIT WINDOW_EVENTS  FILE_EVENTS
                                  TIMER_EVENTS IDLE_EVENTS ALL_EVENTS);
@EXPORT_OK = (@misc, @perlTk, @eventFlags );
%EXPORT_TAGS = (widgets => [], misc => \@misc, perlTk => \@perlTk,
                eventtypes => [@eventFlags],
                );

## TODO -- module's private $tkinterp should go away!
my $tkinterp = undef;		# this gets defined when "new" is done

# Hash to keep track of all created widgets and related instance data
# Tcl::Tk will maintain PATH (Tk widget pathname) and INT (Tcl interp)
# and the user can create other info.
%W = (
    INT => {},
    PATH => {},
    RPATH => {},
    DATA => {},
    MWID => {},
);
# few shortcuts for %W to be faster
$Wint = $W{INT};
$Wpath = $W{PATH};
$Wdata = $W{DATA};



# hash to keep track on preloaded Tcl/Tk modules, such as Tix, BWidget
my %preloaded_tk; # (interpreter independent thing. is this right?)

#
sub new {
    my ($class, $display) = @_;
    Carp::croak 'Usage: $interp = new Tcl::Tk([$display])'
	if @_ > 1;
    my @argv;
    if (defined($display)) {
	push(@argv, -display => $display);
    } else {
	$display = $ENV{DISPLAY} || '';
    }
    my $i = new Tcl;
    bless $i, $class;
    $i->SetVar2("env", "DISPLAY", $display, Tcl::GLOBAL_ONLY);
    $i->SetVar("argv", [@argv], Tcl::GLOBAL_ONLY);
    $i->SetVar("tcl_interactive", 0, Tcl::GLOBAL_ONLY);
    $i->SUPER::Init();
    $i->pkg_require('Tk', $i->GetVar('tcl_version'));
    # $i->update; # WinCE helper. TODO - remove from RELEASE
    my $mwid = $i->invoke('winfo','id','.');
    $W{PATH}->{$mwid} = '.';
    $W{INT}->{$mwid} = $i;
    $W{MWID}->{'.'} = $mwid;
    $W{mainwindow}->{"$i"} = bless({ winID => $mwid }, 'Tcl::Tk::Widget::MainWindow');
    $i->call('trace', 'add', 'command', '.', 'delete',
	 sub { for (keys %W) {$W{$_}->{$mwid} = undef; }});
    $i->ResetResult();
    $Tcl::Tk::TK_VERSION = $i->GetVar("tk_version");
    # Only do this for DEBUG() ?
    $Tk::VERSION = $Tcl::Tk::TK_VERSION;
    $Tk::VERSION =~ s/^(\d)\.(\d)/${1}0$2/;
    unless (defined $tkinterp) {
	# first call, create command-helper in TCL to trace widget destruction
	$i->CreateCommand("::perl::w_del", \&widget_deletion_watcher);
        
	# Create command-helper in TCL to perform the actual widget cleanup
        #   (deferred in a afterIdle call )
	$i->CreateCommand("::perl::w_cleanup", \&widget_cleanup);
    }
    $tkinterp = $i;
    return $i;
}

sub mainwindow {
    # this is a window with path '.'
    my $interp = shift;
    
    
    return $W{mainwindow}->{"$interp"};
}
sub tkinit {
    my $interp = Tcl::Tk->new(@_);
    $interp->mainwindow;
}

sub MainWindow {
    my $interp = Tcl::Tk->new(@_);

    # Load Tile Widgets, if the tcl version is > 8.5
    my $patchlevel = $interp->icall('info', 'patchlevel');
    my (@patchElems) = split('\.', $patchlevel);
    my $versionNumber = $patchElems[0] + $patchElems[1]/1000 + $patchElems[2]/100e3; # convert version to number
    if( $versionNumber >= 8.005 ){
            require Tcl::Tk::Tile;
            Tcl::Tk::Tile::_declareTileWidgets($interp);
    }
    
    # Load palette commands, so $interp->invoke can be used with them later, for speed.
    $interp->call('auto_load', 'tk_setPalette');

    
    # Declare auto-widgets, so subclasses of auto-created widgets will work correctly.
    Tcl::Tk::Widget::declareAutoWidget($interp);
    

    $interp->mainwindow;
}

sub MainLoop {
    # This perl-based mainloop differs from Tk_MainLoop in that it
    # relies on the traced deletion of '.' instead of using the
    # Tk_GetNumMainWindows C API.
    # This could optionally be implemented with 'vwait' on a specially
    # named variable that gets set when '.' is destroyed.
    my $int = (ref $_[0]?shift:$tkinterp);
    my $mwid = $W{MWID}->{'.'};
    while (defined $Wpath->{$mwid}) {
	$int->DoOneEvent(0);
    }
}

# DoOneEvent for compatibility with perl/tk
sub DoOneEvent{
    my $int = (ref $_[0]?shift:$tkinterp);
    my $flags = shift;
    $int->Tcl::DoOneEvent($flags);
}

# After wrapper for compatibility with perl/tk (So that Tcl::Tk->after(delay) calls work
sub after{
    my $int = shift;
    $int = (ref($int) ? $int : $tkinterp ); # if interpreter not supplied use $tkinterp
    my $ms = shift;
    my $callback = shift;
    
    if( defined($callback)){
            # Turn into callback, if not one already
            unless( blessed($callback) and $callback->isa('Tcl::Tk::Callback')){
                    $callback = Tcl::Tk::Callback->new($callback);
            }
            
            my $ret = $int->call('after', $ms, sub{ $callback->Call()} );
            return $int->declare_widget($ret);
    }
    else{ # No Callback defined, just do a sleep
            return $int->call('after', $ms );
    }
    
    return($int->call('after', $ms));
}


# create_widget Method
#   This is used as a front-end to the declare_widget method, so that -command  and -variable configuration
#    options supplied at widget-creation will be properly stored as Tcl::Tk::Callback objects (for perltk
#    compatibility).
#   This is done by issuing the -command or -variable type option after widget creation, where the callback object can be
#    stored with the widget
sub create_widget{
    my $int      = shift; # Interperter
    my $parent   = shift; # Parent widget
    my $id       = shift; # unique id for the new widget
    my $ttktype  = shift; # Name of widget, in tcl/tk 
    my $widget_class = shift || 'Tcl::Tk::Widget';

    my @args = @_;
    
    my @filteredArgs;   # args, filtered of any -command type options
    my @commandOptions; # any command options needed to be issued after widget creation.
    
    # Go thru each arg and look for callback (i.e -command ) args
    my $lastArg;
    foreach my $arg(@args){
            
            if( defined($lastArg) && !ref($lastArg) && ( $lastArg =~ /^-\w+/ ) ){
                    if(  $lastArg =~ /command|cmd$/ && defined($arg) ) {  # Check for last arg something like -command
            
                            #print "Found command arg $lastArg => $arg\n";
                            
                            # Save this option for issuing after widget creation
                            push @commandOptions, $lastArg, $arg;
                            
                            # Remove the lastArg from the current arg queue, since we will be handling
                            #  it using @commandOptions
                            pop @filteredArgs;
                            
                            $lastArg = undef;
                            next;
                    }
                    if(  $lastArg =~ /variable$/ ){  # Check for last arg something like -textvariable
                            # Save this option for issuing after widget creation
                            push @commandOptions, $lastArg, $arg;
                            
                            # Remove the lastArg from the current arg queue, since we will be handling
                            #  it using @commandOptions
                            pop @filteredArgs;
                            
                            $lastArg = undef;
                            next;
                    }

            }
            
            $lastArg = $arg;
            
            push @filteredArgs, $arg;
    }
    
    # Make the normal declare_widget call
    my $widget = $int->declare_widget($parent->call($ttktype, $id, @filteredArgs), $widget_class);
    
    # Make configure call for any left-over commands
    $widget->configure(@commandOptions) if(@commandOptions);
    
    return $widget;
}
    
    
#
# declare_widget, method of interpreter object
# args:
#   - a path of existing Tcl/Tk widget to declare its existance in Tcl::Tk
#   - (optionally) package name where this widget will be declared, default
#     is 'Tcl::Tk::Widget', but could be 'Tcl::Tk::Widget::somewidget'
sub declare_widget {
    my $int = shift;
    my $path = shift;
    my $widget_class = shift || 'Tcl::Tk::Widget';
    # JH: This is all SOOO wrong, but works for the simple case.
    # Issues that need to be addressed:
    #  1. You can create multiple interpreters, each containing identical
    #     pathnames.  This var should be better scoped.
    #	  VK: mostly resolved, such interpreters with pathnames allowed now
    #  2. There is NO cleanup going on.  We should somehow detect widget
    #     destruction (trace add command delete ... in 8.4) and interp
    #     destruction to clean up package variables.
    #my $id = $path=~/^\./ ? $int->invoke('winfo','id',$path) : $path;
    $int->invoke('trace', 'add', 'command', $path, 'delete', "::perl::w_del $path")
        if ( WIDGET_CLEANUP && $path !~ /\#/); # don't trace for widgets like 'after#0'
    my $id = $path;
    my $w = bless({ winID => $id}, $widget_class);
    Carp::confess("id is not found\n") if( !defined($id));
    $Wpath->{$id} = $path; # widget pathname
    $Wint->{$id}  = $int; # Tcl interpreter
    $W{RPATH}->{$path} = $w;
    
    
    return $w;
}

sub widget_deletion_watcher {
    my (undef,$int,undef,$path) = @_;
    #print  STDERR "[D:$path]\n";
    
    # Call the _OnDestroy method on the widget to perform cleanup on it
    my $w = $W{RPATH}->{$path};
    #print STDERR "Calling _Destroyed on $w, Ind = ".$Idelete++."\n";
    $w->_Destroyed();
    
    $int->delete_widget_refs($path);

    delete $W{RPATH}->{$path};
}

###############################################
#  Overriden delet_ref
#  Instead of immediately deleting a scalar or code ref in Tcl-land,
#   queue the ref to be deleted in an after-idle call.
#   This is done, rather than deleting immediately, because an immediate delete
#   before a widget is completely destroyed can causes Tcl-crashes.
sub delete_ref {
    my $interp = shift;
    my $rname = shift;
    my $ref = $interp->return_ref($rname);
    push @cleanup_refs, $rname; 
    
    # Create an after-idle call to delete refs, if the cleanup queue is bigger
    #   than the threshold
    if( !$cleanupPending and scalar(@cleanup_refs) > $cleanup_queue_maxsize ){
            #print STDERR "Calling after idle cleanup on ".join(", ", @cleanup_refs)."\n";
            $cleanupPending = 1; # Setup flag so we don't call the after idle multiple times
            $interp->call('after', 'idle', "::perl::w_cleanup");
    }
    return $ref;
}


# Sub to cleanup any que-ed commands and variables in
#  @cleanup_refs. This usually called from an after-idle procedure
sub widget_cleanup {
    my (undef,$int,undef,$path) = @_;

    my @deleteList = @cleanup_refs;
    
    # Go thru each list and delete
    foreach my $rname(@deleteList){
            #print  STDERR "Widget_Cleanup deleting $rname\n";

            $int->SUPER::delete_ref($rname);
    }
    
    # Zero-out cleanup_refs
    @cleanup_refs = ();
    $cleanupPending = 0; # Reset cleanup flag for next time

}

# widget_data return anonymous hash that could be used to hold any 
# user-specific data
sub widget_data {
    my $int = shift;
    my $path = shift;
    $Wdata->{$path} ||= {};
    return $Wdata->{$path};
}

# subroutine awidget used to create [a]ny [widget]. Nothing complicated here,
# mainly needed for keeping track of this new widget and blessing it to right
# package
sub awidget {
    my $int = (ref $_[0]?shift:$tkinterp);
    my $wclass = shift;
    # Following is a suboptimal way of autoloading, there should exist a way
    # to Improve it.
    my $sub = sub {
        my $int = (ref $_[0]?shift:$tkinterp);
        my ($path) = $int->call($wclass, @_);
        return $int->declare_widget($path);
    };
    unless ($wclass=~/^\w+$/) {
	die "widget name '$wclass' contains not allowed characters";
    }
    # create appropriate method ...
    no strict 'refs';
    *{"Tcl::Tk::$wclass"} = $sub;
    # ... and call it (if required)
    if ($#_>-1) {
	return $sub->($int,@_);
    }
}
sub widget($@) {
    my $int = (ref $_[0]?shift:$tkinterp);
    my $wpath = shift;
    my $wtype = shift || 'Tcl::Tk::Widget';
    if (exists $W{RPATH}->{$wpath}) {
        return $W{RPATH}->{$wpath};
    }
    unless ($wtype=~/^(?:Tcl::Tk::Widget)/) {
	Tcl::Tk::Widget::create_widget_package($wtype);
	$wtype = "Tcl::Tk::Widget::$wtype";
    }
    #if ($wtype eq 'Tcl::Tk::Widget') {
    #	require Carp;
    #	Carp::cluck("using \"widget\" without widget type is strongly discouraged");
    #}
    # We could ask Tcl about it by invoking
    # my @res = $int->Eval("winfo exists $wpath");
    # but we don't do it, as long as we allow any widget paths to
    # be used by user.
    my $w = $int->declare_widget($wpath,$wtype);
    return $w;
}

sub Exists($) {
    my $wid = shift;
    return 0 unless defined($wid);
    if (ref($wid)=~/^Tcl::Tk::Widget\b/) {
        my $wp = $wid->path;
        my $interp = $wid->interp;
        return 0 unless( defined $interp); # Takes care of some issues during global destruction
        return $interp->icall('winfo','exists',$wp);
    }
    return eval{$tkinterp->icall('winfo','exists',$wid)};
}
# do this only when tk_gestapo on?
# In normal case Tcl::Tk::Exists should be used.
#*{Tk::Exists} = \&Tcl::Tk::Exists;

sub widgets {
    \%W;
}

sub pkg_require {
    # Do Tcl package require with optional version, cache result.
    my $int = shift;
    my $pkg = shift;
    my $ver = shift;

    my $id = "$int$pkg"; # to made interpreter-wise, do stringification of $int

    return $preloaded_tk{$id} if $preloaded_tk{$id};

    my @args = ("package", "require", $pkg);
    push(@args, $ver) if defined($ver);
    eval { $preloaded_tk{$id} = $int->icall(@args); };
    if ($@) {
	# Don't cache failures, as the package may become available by
	# changing auto_path and such.
	return;
    }
    return $preloaded_tk{$id};
}

sub need_tk {
    # DEPRECATED: Use pkg_require and call instead.
    my $int = shift;
    my $pkg = shift;
    my $cmd = shift || '';
    warn "DEPRECATED CALL: need_tk($pkg, $cmd), use pkg_require\n";
    if ($pkg eq 'ptk-Table') {
        require Tcl::Tk::Table;
    }
    else {
	# Only require the actual package once
	my $ver = $int->pkg_require($pkg);
	return 0 if !defined($ver);
	$int->Eval($cmd) if $cmd;
    }
    return 1;
}

sub tk_gestapo {
    # When placed first on the INC path, this will allow us to hijack
    # any requests for 'use Tk' and any Tk::* modules and replace them
    # with our own stuff.
    my ($coderef, $module) = @_;  # $coderef is to myself
    return undef unless $module =~ m!^Tk(/|\.pm$)!;

    my ($package, $callerfile, $callerline) = caller;
    

    my $fakefile;
    open(my $fh, '<', \$fakefile) || die "oops";

    $module =~ s!/!::!g;
    $module =~ s/\.pm$//;

    # Make Version if importing Tk (needed for some scripts to work right)
    my $versionText = "\n";
    if( $module eq 'Tk' ){
            $versionText = '$Tk::VERSION = 805.001;'."\n";
            
            # Redefine common Tk subs/variables to Tcl::Tk equivalents
            no warnings;
            *Tk::findINC = \&Tcl::Tk::findINC;
            
    }


    $fakefile = <<EOS;
package $module;
$versionText
warn "### $callerfile:$callerline not really loading $module ###";
sub foo { 1; }
1;
EOS
    return $fh;
}

# subroutine findINC copied from perlTk/Tk.pm
sub findINC {
    my $file = join('/',@_);
    my $dir;
    $file  =~ s,::,/,g;
    foreach $dir (@INC) {
	my $path;
	return $path if (-e ($path = "$dir/$file"));
    }
    return undef;
}



# sub Declare is just a dispatcher into Tcl::Tk::Widget method
sub Declare {
    Tcl::Tk::Widget::Declare(undef,@_[1..$#_]);
}


#
# AUTOLOAD method for Tcl::Tk interpreter object, which will bring into
# existance interpreter methods
sub AUTOLOAD {
    my $int = shift;
    my ($method,$package) = $Tcl::Tk::AUTOLOAD;
    my $method0;
    for ($method) {
	s/^(Tcl::Tk::)//
	    or die "weird inheritance ($method)";
	$package = $1;
        $method0 = $method;
	s/(?<!_)__(?!_)/::/g;
	s/(?<!_)___(?!_)/_/g;
    }
 
    # if someone calls $interp->_method(...) then it is considered as faster
    # version of method, similar to calling $interp->method(...) but via
    # 'invoke' instead of 'call', thus faster
    my $fast = '';
    $method =~ s/^_// and do {
	$fast='_';
	if (exists $::Tcl::Tk::{$method}) {
	    no strict 'refs';
	    *{"::Tcl::Tk::_$method"} = *{"::Tcl::Tk::$method"};
	    return $int->$method(@_);
	}
    };

    # search for right corresponding Tcl/Tk method, and create it afterwards
    # (so no consequent AUTOLOAD will happen)

    # Check to see if it is a camelCase method.  If so, split it apart.
    # code below will always create subroutine that calls a method.
    # This could be changed to create only known methods and generate error
    # if method is, for example, misspelled.
    # so following check will be like 
    #    if (exists $knows_method_names{$method}) {...}
    my $sub;
    if ($method =~ /^([a-z]+)([A-Z][a-z]+)$/) {
        my ($meth, $submeth) = ($1, lcfirst($2));
	# break into $method $submethod and call
	$sub = $fast ? sub {
	    my $int = shift;
	    $int->invoke($meth, $submeth, @_);
	} : sub {
	    my $int = shift;
	    $int->call($meth, $submeth, @_);
	};
    }
    else {
	# Default case, call as method of $int
	$sub = $fast ? sub {
	    my $int = shift;
	    $int->invoke($method, @_);
	} : sub {
	    my $int = shift;
	    $int->call($method, @_);
	};
    }
    no strict 'refs';
    *{"$package$fast$method0"} = $sub;
    Sub::Name::subname("$package$fast$method0", $sub) if( $Tcl::Tk::DEBUG);
    return $sub->($int,@_);
}

# Sub to support the "Ev('x'), Ev('y'), etc" syntax that perltk uses to supply event information
#   to bind callbacks. This sub-name is exported with the other perltk subs (like MainLoop, etc).
sub Ev {
    my @events = @_;
    return bless \@events, "Tcl::Tk::Ev";
}

# Tcl::Tk::break, used to break out of event bindings (i.e. don't process anymore bind subs after break is called).
#   This is handled by the wrapper tcl code setup in Tcl::Tk::bind
sub break
{
 # Check to see if we are being called from Tcl::Tk::Callback, if so, then this is a valid 'break' call
 #   and we will die with _TK_BREAK_
 my @callInfo;
 my $index = 0;
 my $callback;  # Flag = 1 if this is a callback
 while (@callInfo = caller($index)){
         #print STDERR "Break Caller = ".join(", ", @callInfo)."\n";
         if( $callInfo[3] eq 'Tcl::Tk::Callback::BindCall'){
                 $callback = 1;
         }
         $index++;
 }

 die "_TK_BREAK_\n" if($callback);
 
}

# Wrappers for the Event Flag subs in Tcl (for compatiblity with perl/tk code
sub DONT_WAIT{ Tcl::DONT_WAIT()};        
sub WINDOW_EVENTS{ Tcl::WINDOW_EVENTS()};        
sub FILE_EVENTS{ Tcl::FILE_EVENTS()};        
sub TIMER_EVENTS{ Tcl::TIMER_EVENTS()};        
sub IDLE_EVENTS{ Tcl::IDLE_EVENTS()};        
sub ALL_EVENTS{ Tcl::ALL_EVENTS()};        

1;
