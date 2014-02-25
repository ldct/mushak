#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: data.tcl
# 
## Persistent object management. Persistent objects replicate the content of
## a filesystem directories with certain requirements: 
##<ol>
##  <li> they belong to a class defined by a hidden file 
##       <code>.class.tcl</code> in that dir </li>
##  <li> there is a tcl module with the same class name defining 
##       attributes and opeprations</li>
##  <li> sub-directories correspond to the class attribute definition </li>
##  <li> atomic data is recorded in a hidden file 
##       <code>.data.tcl</code> in that dir</li>
##</ol>
## Class names should be capitalized. The module must contain an Attributes
## declaration (defined in this module) and several Operation declaration
## (also defined in this module). 
##
## A class definition may include a special operations to be automatically 
## execute when an object is 
## <ul>
##	<li>	<code>_create_</code>
##	<li>	<code>_update_</code>
##	<li>	<code>_destroy_</code>
## <ul>
##
## Include a procedures for loading data from a CGI communication that
## probably would be better placed in another package.

package provide data 1.0

package require cgi
catch { source lib/cgi.tcl }	;# ?? 

namespace eval data {

    variable Base 	data		;# base directory
    variable Data_file	.data.tcl	;# filename with directory data
    variable Class_file .class.tcl	;# filename with directory class
    variable Segment	0		;# number of created data segments
    variable Type			;# regular expressions defining type ?
    variable Attributes			;# attributes array indexed on type
    variable Operations			;# operations array indexed on type
    variable Undef	""		;# undefined values
    variable IncTab	10		;# tabbing increment (XML export)
    variable DIFF	/usr/bin/diff	;# Unix diff command
}

## Attribute definition
proc Attributes {class attributes} {
 
    namespace eval ::$class {}
    if [ expr [ llength $attributes ] % 3 == 0 ] {
	namespace eval data [  list set Attributes($class) $attributes ]
    } else {
	error "invalid attribute declaration in $class"
    }
}

## Operation definition (equivalent to a proc)
proc Operation {proc arguments def} {
    if [ regexp {^([^:]+)::(.+)$} $proc - class name ] {
	namespace eval data [  list lappend Operations($class) $name ]
	proc $proc $arguments "upvar dir _Self_ \n data::attributes \n $def"
    } else {
	error "invalid operation: $proc"
    }
}

#-----------------------------------------------------------------


## Creates a new data directory
proc data::new {dir class} {
    variable Class_file
    variable Data_file

    file mkdir $dir
    file attributes $dir -permissions u=rwx,g=x,o=x
    set fd [ ::open $dir/$Class_file w ]
    puts $fd "return $class"
    catch { ::close $fd } erro

    set fd [ ::open $dir/$Data_file w ]
    puts -nonewline $fd ""
    catch { ::close $fd }
    
    set out [ ::data::open $dir 2]
    
    # if a _create_ method is defined then it is execute
    if { [ info procs ::${class}::_create_ ] != {} } {
	write $dir
	method $dir _create_
	write $dir
    }

    return $out
}


## Opens directory into a data segment :-(BAD name, collides with ::open)
## Open dirs are not reloaded
proc data::open {dir {level 1}} {
    variable Data

    if [ info exists Data($dir) ] {
	set data $Data($dir)
    } else {
	variable Class_file
	variable Data_file

	set class [ source $dir/$Class_file ]
	set data [ soul $dir $class [ expr $level + 1] ] 
	if [ catch {
	    namespace eval $data [ list source $dir/$Data_file ]
	} msg ] {
	    execute::record_error [ format {'%s' while loading %s} $msg $dir ]
	}
	    
    }
    return $data

}

## Not in use: convert sourced files to current encoding
proc data::encoding_source {source_file} {
     
	set encoding [ encoding system ]	;# this system encoding
     	if { ! [ catch { ::open $source_file r } fid ] } {
       		if { ! [ catch { fconfigure $fid -encoding $encoding } msg ] } {
			set script [read $fid]
	 		catch {::close $fid}
       		} else {
	 		# make sure channel gets closed
	 		catch {close $fid}
	 		return -code error "unknown encoding \"$encoding\""
       		}
     	} else {
	 	# return error message similar to source cmd
	 	return -code error "$msg\ncouldn't read file \"$source_file\": no such file or directory"
     	}
     	# not sure if this has to be catched as well to propagate the error code to the caller
     	# to imitate the original source cmds behaviour.
     	uplevel 1 $script
}


## Creates a data object (soul :-) associated with a directory
proc data::soul {dir class {level 1}} {
    variable Class
    variable Data

    # class
    set Class($dir) $class
    namespace eval ::$Class($dir) {}
    # package require $Class($dir)

    # data
    set Data($dir)  [ namespace current ]::$dir   
    namespace eval $Data($dir) {}

    # methods
    package require $Class($dir)
    proc ::$dir args [ format { data::method %s $args } $dir ]

    return $Data($dir)
}

## Destroy a persistent object
proc data::destroy {dir} {
    variable Class
    variable Data

    # if a _destroy_ method is defined then it is execute
    if { [ info procs ::$Class($dir)::_destroy_ ] != {} } {
	method $dir _destroy_
    }

    data::close $dir
}

## Closes a persistent object
proc data::close {dir} {
    variable Class
    variable Data

    namespace delete $Data($dir)    
}

## Records the data segment in its original directory
proc data::record {dir} {
    variable Class

    write $dir
    # if an update method is defined then it is execute
    if { [ info procs ::$Class($dir)::_update_ ] != {} } {
	set propagate [ method $dir _update_ ]
	write $dir
	# propagate to parent directory
	if $propagate {
	    set par [ file::canonical_pathname $dir/.. ]
	    data::open $par
	    data::record $par
	}
    }
}

## Writes data back to directory
proc data::write {dir} {
    variable Attributes
    variable Data_file
    variable Class
    variable Data
    variable DIFF
    variable ::file::TMP

    set tmp $TMP/${Data_file}

    set fd [ ::open $tmp w ]

    set more_attributes $Attributes($Class($dir))
    while { $more_attributes != "" } {
	set attributes $more_attributes
	set more_attributes {}

	foreach  {var type comp} $attributes {

	    if { [ info exists $Data($dir)::${var} ] } {
		set value [ namespace eval $Data($dir) [ list set $var ] ]
	    } else {
		namespace eval $Data($dir) [ list  set $var [ set value "" ] ]
	    }
	    puts $fd [ format {set %12s %s} $var [ list $value ] ]
    
	    if [ string equal $type choice ] {
		more_attributes $comp $value more_attributes
	    }
	}
    }
    catch { ::close $fd }
    if [ catch { exec $DIFF $tmp $dir/$Data_file } msg ] {
	file rename -force -- $tmp $dir/$Data_file
    } else {
	file delete -force -- $tmp
    }
    
}

# writes single data item
proc data::write_item {fd dir var} {
    return $value
}


## Return class for pathname
proc data::class {dir} {
    variable Class_file
    
    if { [ file readable $dir/$Class_file ] } {
	return [ source $dir/$Class_file ]
    } else {
	return {}
    }
    
}

## Return list of classes for pathname
proc data::subclasses {dir} {
    variable Attributes
    variable Class

    ::data::open $dir

    set sub {}     
    foreach  {var type comp}	$Attributes($Class($dir)) {
	switch type {
	    choice {
		error "FIX ME !!!"
	    }
	    dir { ;# should dir be included ?
	    }		
	    dirs {
		lappend sub $comp
	    }
	}
    }

    return $comp
}

## Return list of classes for pathname
proc data::descendents {dir {class {}}} {

    set candidates [ glob -nocomplain -type d $dir/* ]

    if { $class == "" } {
	set descendents $candidates
    } else {
	set descendents {}
	foreach dir $candidates {
	    if [ string equal [ ::data::class $dir ] $class ] {
		lappend descendents $dir
	    }
	}
    }
    return $descendents
}


## Invokes a method based on objects class
proc data::method {dir arguments} {
    variable Class

    set method	[ lindex $arguments 0 ]
    set args	[ lrange $arguments 1 end ]

    set result [ eval $Class($dir)::$method $args ]

    return $result
}

## Defines attributes within a method
proc data::attributes {} {
    variable Attributes
    variable Data
    variable Class
    variable Undef

    upvar 2 dir dir
    
    set more_attributes $Attributes($Class($dir))
    while { $more_attributes != "" } {
	set attributes $more_attributes
	set more_attributes {}

	foreach {var type comp} $attributes {
	    if { ! [ info exists $Data($dir)::$var ] } {
		set $Data($dir)::$var $Undef
	    }	
	    
	    uplevel 1 upvar $Data($dir)::$var $var
	    if [ string equal $type choice ] {
		more_attributes $comp [ set $Data($dir)::$var ] more_attributes
	    }
	}
    }
}

## Append more attributes to a list ...
proc data::more_attributes {attributes value more_attributes_} {
    upvar $more_attributes_ more_attributes

    foreach {var type comp} $attributes {
	if [ string equal $value $var ] {
	    lappend more_attributes $var $type $comp 
	    return
	}
    }
}

## Return current directory
proc data::directory {} {
    upvar 2 dir dir
    return $dir
}

## Checks if variable is defined and has a non null value
proc data::check {var} {
    upvar $var v
    variable Undef

    if { ! [ info exists v ] } {
	error [ format {%s: %s} \
		    [ translate::sentence "undefined variable"] $var ]
    }

    if { [ string compare $v $Undef ] == 0 } {
	error [ format {%s: %s} \
		    [ translate::sentence "variable with null value"] $var ]

    }
}


