#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Balloons.tcl
# 
## Set of ballons delivered during a contest and related operations
#


package provide Balloons 1.0

namespace eval Balloons {

}

#-----------------------------------------------------------------------------
#     Class definition


Attributes Balloons {
    List-Pending	menu 	{yes no}
    Balloon		dirs	Balloon
}

## Check if a ballon for this team/problem has already been filled
Operation Balloons::filled {team problem} {

    foreach sub [ glob -type d -nocomplain ${_Self_}/* ] {

	set seg [ data::open $sub ]

	upvar ${seg}::Team Team
	upvar ${seg}::Problem Problem
	if { 
	    [ info exists Team ] 					&& 
	    [ info exists Problem ] 					&& 
	    [ string compare 	$team 		$Team 		] == 0	&&
	    [ string compare 	$problem 	$Problem 	] == 0
	} {
	    return 1
	}
    }
    return 0
}


## Checks if directory is empty
Operation Balloons::check {} {

    check::dir_start 0
    check::dir_empty
    check::dir_end 0
}

## Cleans ballons from directory
Operation Balloons::prepare {} {
    check::clear 
} 

## Lists balloons
Operation Balloons::balloons {{profile admin}} {
    set message ""

    listing::header message

    set problem [ cgi::field problem "" ]
    set team	[ contest::team ]

    set list [ listing::restrict ${_Self_} ] 
    set list [ lsort -command						  \
		   [ list listing::cmp [ list _${problem}_ _${team}\$ ] ] \
		   $list ]
    set all_subs [ lsort -decreasing [ listing::unrestrict ${_Self_} ] ]
    set n_subs   [ llength $all_subs ]


    listing::part list pages last n

    foreach sub $list {
	if [ catch {
	    set m [ expr $n_subs - [ lsearch $all_subs $sub ] ]
	    data::open $sub
	    $sub listing_line $m $n $profile
	} ] {
	    incr n
	    # DONT SHOW CORRUPTED LINES
	    #set m $n
	    #layout::toggle_color m color
	    #template::write empty
	}
	incr n -1
    }

    listing::footer [ incr n ] $pages $list 
}
