#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: check.tcl
# 
## The procedures in this package are used for checking the current 
## contest for errors that may prevent it from starting. A listing is
## produced showing these errors that may be of three categories
##
##	Fatal 		the contest cannot start
##	Warnings	should be fixed but the contest may start
##	Trash		Will be automatically repaired (files to be removed)

package provide check 1.0

namespace eval check {
    variable Fatal	0	;## Count of fatal errors (contest cannot start)
    variable Warning	0	;## Count of warnings  (contest may start)
    variable Trash	0	;## Count of situations repaired by preparetion
    variable Old	""	;## Fatal errors before checking

    variable F			;## Formats
    array set F {
	simple	{%s<br>}
	var	{%s <code>%s</code><br>}			     
	value	{%s <code>%s</code>: %s<br>}
	dir	{%s <a target='select' href='%s'><code>%s</code></a><br>}
    }
}

## Record a message in a given variable
proc check::record {report_ format message args} {
    upvar $report_ report
    variable F

    append report [ eval format [ list $F($format) ] \
		       [ list [ translate::sentence $message ] ] $args ]
}

## Report errors in sub directories to the variable named in report_
proc check::dirs {report_ _Self_} {
    upvar $report_ report

    set n 0

    # _Self_ is not the best of names for a parameter, but check::attribute
    # is expecting this variable to be defined in the calling procedure
    foreach path [ glob -nocomplain -type d ${_Self_}/* ] {
	set dir [ file tail $path ]
	check::attribute report $dir dir
	incr n
    }
    return $n
}

## Resets reporting variables before start reporting
proc check::reset {fatal_ {warning_ ""}} {
    variable Old
    upvar $fatal_ fatal

    set Old $fatal
    set fatal ""

    if { $warning_ != "" } {
	upvar $warning_ warning
	set warning ""
    }
}

## Is propagation to the parent needed because fatal errors changed?
proc check::requires_propagation {fatal} {
    variable Old

    return [ string compare $fatal $Old ]
}

## Check if execute is available 
proc check::execute {fatal_ execute {package ""}} {
    upvar $fatal_ fatal

    if { ! [ file executable $execute ] } {
	if { $package == "" } {
	    set package [ file tail $execute ]
	}
	record fatal value "Please install package" $package $execute
	layout::alert [ format "\n Please install package %s in %s \n" \
			    $package $execute  ]
    }
}


## Check an attribute value and report to given variable
proc check::attribute {report_ var {type ""} } {
    variable ::Session::Conf
    upvar $report_	report
    variable F

    switch $type {
	{}  {
	    upvar $var value
	    if { $value == "" } {
		record report var "Undefined variable" \
		    [ translate::sentence $var ]
	    }
	}
	fx   {
	    upvar $var fx
	    upvar _Self_ dir

	    if { ! [ file readable $dir/$fx ] } {
		record report value "Unreadable file" \
		    [ translate::sentence $var ] $fx
	    }
	}
	dir  {
 	    upvar _Self_ dir
	    
	    if { ! [ file readable $dir/$var ] } {
		record report var "Unreadable directory"  $var
	    } else {
		if { 
		    ! [ catch {	set obj [ data::open $dir/$var ] } ] &&
		    ( ! [ info exists ${obj}::Fatal ] ||
		      [ set ${obj}::Fatal ] != "" )
		} {
		    record report dir "Check" $Conf(controller)?data+$dir/$var $var
		}
	    }
	}
	transactions {
 	    upvar _Self_ dir
	    
	    if { ! [ file readable $dir/$var ] } {
		record report var "Unreadable directory" $var
	    } elseif { [ glob -nocomplain -type d $dir/$var/* ] != {} } {
		record report dir "Non empty directory" $Conf(controller)?data+$dir/$var $var
	    }
	}
	default {
	    upvar $var value
	    if { ! [ regexp $type $value ] } {
		record report value "Variable with invalid value" \
		    [ translate::sentence $var ] $value

	    }
	}
    }
}

##--------------------------------------------------------------------------

## Header of listing
proc check::head {designation missing} {
    global REL_BASE

    template::load check/check
    template::record head
}

# Hooter of listing
proc check::foot {} {
    variable Fatal
    variable Warning
    variable Trash
    
    template::record foot
}

## Start checking a directory
proc check::dir_start {{top 0}} {
    upvar _Self_ dir

    set name [ file tail $dir ] 
    regsub -all _ $name { } name
    if { [ expr [ file attributes $dir -permissions ] & 0020 ] } {
	set name [ translate::sentence $name ]
    }
    if $top {
	template::record top_head
    } else {
	template::record dir_head
    }    
}

## Completes checking a directory
proc check::dir_end {{top 0}} {

    if $top {
	template::record top_foot check
    } else {
	template::record dir_foot check
    }
}

## Checks sub-dirs (returns its number)
proc check::sub_dirs {} {
    upvar _Self_ dir

    set n 0
    foreach sdir [ glob -type d -nocomplain $dir/* ] {
	data::open $sdir
	$sdir check
	incr n
    }
    return $n
}

## DEPRECATED !!
## Checks if vars in args are defined in current directory
proc check::vars {args} {
    foreach var $args {
	switch [ llength $var ] {
	    2 {
		foreach {name type} $var {}
		if { ! [ regexp $type [ uplevel set $name ] ] } {
		    report_error Fatal "Variable with invalid value"  \
			[ format {%s := %s} $name [ uplevel set $name ] ]
		}
	    }
	    1 { 
		if { [ uplevel set $var ] == "" } {
		    report_error Warning "Undefined variable" \
			[ translate::sentence $var ]
		}
	    }
	}
    }
}




## Checks if files passed in args are defined in current directory
proc check::fxs {args} {
    upvar _Self_ dir
    
    foreach var $args {
	upvar $var fx
	if { ! [ file readable $dir/$fx ] } {
	    report_error Fatal "Field with unreadable file" \
		[ format {%s: %s} $var $fx ]
	}
    }
}

## Checks if current directory is empty
proc check::dir_empty {} {
    upvar _Self_ dir

    if { [ set n [ llength [ glob -nocomplain $dir/* ] ] ] != 0 } {
	report_error Trash "Directory should be empty" \
	    [ format {%s: %s} $n [ file tail $dir ] ]
    }
}

## Move content of current directory to the trash
proc check::clear {} {
    upvar _Self_ dir
    
    set class [ data::class $dir ]
    set name   [ file tail $dir ]

    set copy $dir/../../../trash/$name
    data::new $copy $class 

    foreach cnt [ glob -nocomplain $dir/* ] {
	file::move $cnt $copy
    }

}

## Marks an error; types in { Fatal Warning Trash }
proc check::report_error {type message {value ""}} {
    variable $type
    
    set message 
    
    set message [ format {%s: <code>%s</code>} \
		      [ translate::sentence $message ] $value ]
    
    incr $type
    template::record $type check
}
