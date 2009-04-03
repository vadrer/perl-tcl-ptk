

package Tcl::Tk::Widget::HList;

@Tcl::Tk::Widget::HList::ISA = (Tcl::Tk::Widget);

use strict;

use Carp;

# Wrapper method for the -indicatorcmd (thru the %replace_options hash in Tcl::Tk::Widget)
#
# perltk's HList -indicatorcmd expects to see the pathname and the event type supplied to the callback.
#  tixHlist -indicatorcmd only defines the pathname to be supplied, So we have to supply an interfacing
#  routine for this option to emulate the perltk behaivor.
sub _procIndicatorCmd{
        my $self = shift;
        my $value = shift;
                
        if( ref($value) ne 'CODE' and ref($value) ne 'ARRAY' ){
                croak("Error in ".__PACKAGE__."::_procIndicatorCmd Supplied value for -indicatorcmd is not a code or array reference\n");
        }
        
        my $callback = Tcl::Tk::Callback->new($value);
        
        $self->{_indicatorcmd} = $callback;
        
        
        # -indicatorcmd supplied to the tcl widget is created here
        my $tclcmd = sub{
                my $entry = shift;
                my $event = $self->call('tixEvent', 'type'); # get the event type usign tixEvent
                $self->{_indicatorcmd}->Call($entry, $event);
        };
        
        $self->call($self->path, 'configure', -indicatorcmd => $tclcmd)
}
                

# Overriden version of add that handles storing any -data option,
#   because the interface between perl and tcl doesn't allow for tie-ing of
#   arbitrary variable references (only scalar and hash references supported now)
sub add
{
        my $self = shift;
        my $item = shift;
        
        
        my %args = @_;
        
        if( defined($args{-data})  ){
                my $data = delete $args{-data};
                #     
                $self->{_HListdata}{$item} = $data;
        }
        
        $self->SUPER::add($item, %args);
}


# Overriden version of entryconfigure that handles storing any -data option,
#   because the interface between perl and tcl doesn't allow for tie-ing of
#   arbitrary variable references (only scalar and hash references supported now)
sub entryconfigure{
        my $self = shift;
        my $item = shift;
        
        
        my %args = @_;
        
        if( defined($args{-data})  ){
                my $data = delete $args{-data};
                #     
 
                
                $self->{_HListdata}{$item} = $data;
                
                return unless( %args); # Don't call parent method if no more args
        }
        
        return $self->SUPER::entryconfigure($item, %args);
        
}

# Overriden version of addChild that handles storing any -data option,
#   because the interface between perl and tcl doesn't allow for tie-ing of
#   arbitrary variable references (only scalar and hash references supported now)
sub addchild{
        my $self = shift;
        my $parentPath = shift;
        
        
        my %args = @_;
        
        if( defined($args{-data})  ){
                my $data = delete $args{-data};
                #     
 
                my $item = $self->SUPER::addchild($parentPath, %args);

                
                $self->{_HListdata}{$item} = $data;
                return $item;
        }
        
        return $self->SUPER::addchild($parentPath, %args);
        
}

# Overriden version of delete that handles delete any -data option dadta
sub delete{
        my $self   = shift;
        my $option = shift;

        my $HListdata = $self->{_HListdata} || {};
        
        my $separator = $self->cget(-separator);

        if( $option eq 'all'){
                %$HListdata = ();
        }
        elsif( $option eq 'entry'){
                my $entry = $_[0];
                delete $HListdata->{$entry};
        }
        elsif( $option eq 'offsprings'){
                my $entry = $_[0];
                
                # Find child keys of entry
                my @deleteKeys = grep /$entry$separator.+/, keys %$HListdata;
                delete @$HListdata{@deleteKeys};
        }
        elsif( $option eq 'siblings'){
                my $entry = $_[0];
                
                # Find child keys of entry
                my @entryComponents = split($separator, $entry);
                
                # Find parent
                pop @entryComponents;
                my $parent = join($separator, @entryComponents);
                
                my @deleteKeys = grep $_ ne $entry && /$parent$separator.+/, keys %$HListdata;
                delete @$HListdata{@deleteKeys};
        }
        
        
        #$self->SUPER::delete($option, @_);
        $self->SUPER::delete($option, @_);
}
 
# Overriden version of info that handles getting -data storage
sub info{
        my $self   = shift;
        my $option = shift;
        
        if( $option eq 'data'){
                my $HListdata = $self->{_HListdata} || {};
                my $item = shift;
                return $HListdata->{$item};
        }
        
        return $self->SUPER::info($option, @_);
}
 
# Overriden version of info that handles getting -data storage
sub entrycget{
        my $self   = shift;
        my $item   = shift;
        my $option = shift;
        
        if( $option eq '-data'){
                my $HListdata = $self->{_HListdata} || {};
                return $HListdata->{$item};
        }
        
        return $self->SUPER::entrycget($item, $option, @_);
}
 
        

1;
