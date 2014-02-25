#
# Mooshak: managing programming contests on the web		APril 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Contests.tcl
# 
## General stuff regarding contests
##
## TODO: Remove deprecated procedures (but check it first)

package provide Contests 1.0

package require data

namespace eval Contests {
    variable Current	data/contest	;# link to current directory
}

Attributes Contests {

    Contest	dirs	Contest

}

## DEPRECATED
# Activates the contest given as parameter (relative to _Self_)
# i.e. creates a symbolic link from $Current to that dir
Operation Contests::activate {{contest {}}} {
    variable Current 

    if { 
	[ file readable $Current ] && 
	[ string equal [ file type $Current ] link ]
    } {
	set prev [ file readlink $Current ]
	data::open $prev
	file delete $Current
    }

    file attributes ${_Self_}  -permissions a+r


    if { $contest != "" } {
	set path ${_Self_}/$contest

	switch [ file pathtype $path ] {
	    relative {
		set path [ pwd ]/$path
	    }
	}

	regexp [ format {%s/(.*)$} [ file dirname $Current ] ] $path - rel
	
	exec ln -s ${rel} $Current
	# deactive other contests using this command raises a lot of problems
	#file attributes ${_Self_}  -permissions a-r
	file attributes $Current  -permissions g+w

	data::open $path
	$path activate
	data::record $path
    }
}

## DEPRECATED ?
## Return the name of active contest (or "" if none)
Operation Contests::active {} {
    variable Current
    
    set contest ""
    catch { set contest [ file tail [ file readlink $Current ] ] } erro

    return $contest
}

## DEPRECATED
## Generates an HTML list with contests names
Operation Contests::list_selector {} {
    variable Current

    set contests ""
    foreach dir [ glob -nocomplain glob ${_Self_}/* ] {
	if { ! [ file isdirectory $dir ] } continue
	set contest [ file tail $dir ]
	if { [ string compare $contest $Current ] == 0 } {
	    set sel " selected"
	} else {
	    set sel ""
	}
	append contests "<option$sel>$contest"
    }
    return $contests
}
