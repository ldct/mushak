#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Checks.tcl
# 
## Directory of Mooshak's check lists 
#

package provide Checks 1.0

package require data
package require Check

Attributes Checks {
    
     Check dirs Check
}

## Lists the available check lists
Operation Checks::show {} {
    variable ::Session::Conf

    template::load     
    template::write head

    foreach fx [ lsort [ glob -nocomplain ${_Self_}/* ] ] {
	if { ! [ file isdirectory $fx ] } continue
	set sv		[ data::open $fx ]
	if { ! [ info exists  ${sv}::Name ] } {
	    template::write check_out
	    continue
	}
	set text	[ set ${sv}::Name ]
	set clist	[ file tail $fx ] 
	template::write check_head

	set first 1
	foreach rep [ lsort -decreasing [ glob -nocomplain $fx/reports/* ] ] {
	    set report [ file tail $rep ]
	    set color blue
	    set style U
	    if [ expr [ file attributes $rep -permission ] & 0040 ] {
		set style B
		if $first { set color red } else { set color "" }
	    } else {
		if $first { set style U } else { set style I }
	    }
	    template::write report
	    set first 0
	}
	template::write check_foot
    }

    template::write foot
    
}

