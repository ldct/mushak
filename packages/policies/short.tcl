#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: short.tcl
# 
## Marking and classification policies for shortest program contests

package provide short 1.0

package require utils

namespace eval short {
    variable Infinity 9999999999 ;# very large program size
    variable Points_from_position;# points from position (first, second, ...)
    set Points_from_position { 4 2 1 }

    # variables used in ranking teams
    variable probs
    variable attpt   
    variable size
    variable time
    variable points	

    # a policy MUST define these procedures
    # view this as a kind of contact or interface
    namespace export subjective	;# is grading subjective?
    namespace export order	;# sort teams by rank
    namespace export rank	;# assign ranks to teams
    namespace export cell	;# show a cell in the classification table
    namespace export solved	;# number of problems solved by team
    namespace export points	;# classification of given team

}

## Is grading subjective (a value given by an human judge)?
proc short::subjective {} {
    return 0
}

## Sort teams by rank
proc short::order {teams problems subs} {
    variable Points_from_position
    variable Infinity
    variable points
    variable probs
    variable attpt   
    variable size
    variable time

    upvar ::Submission::Results Results

    set accepted [ lindex $Results 0 ]

    # initialize
    foreach team $teams {
	set attpt($team) 0
	set size($team) 0
	set points($team) 0
	set probs($team) 0
	foreach problem $problems {
	    set attpt($team,$problem) 0
	    set size($team,$problem) $Infinity
	    set points($team,$problem) 0
	    set time($team,$problem) 0
	}
    }

    # compute points
    foreach sub [ lsort $subs ] {

	if { ! [ Submissions::load_submission $sub ] } continue 

	if { [ lsearch $teams $Team ] == -1 } {
	    execute::record_error "Undefined team '$Team'"	
	    continue
	}

	if { 
	    [ string compare $Classify $accepted ] == 0  &&
	     $Size < $size($Team,$Problem) 
	} {
	    set size($Team,$Problem) $Size
	    set time($Team,$Problem) $Time
	}

	incr attpt($Team)
	incr attpt($Team,$Problem)

    }

    ## grant points to each solved problem 
    ## according to team's position in that problem
    foreach problem $problems {
	set pos 0	

	foreach team \
	    [ lsort -command "::short::compare_sizes ${problem}"  $teams ] {
		if { 
		    [ set tp [ lindex $Points_from_position $pos ] ] == "" ||
		    $size($team,$problem) == $Infinity
		} {
		    set tp 0
		}
		set points($team,$problem) $tp
		incr points($team) $tp
		incr pos
		
		if { $size($team,$problem) != $Infinity } {
		    incr probs($team)
		}
	    }
	
    }


    return [ lsort -command ::short::compare_points $teams ]
}

## Assign ranks to teams
proc short::rank {contest list} {
    variable probs 

    data::open $contest/groups

    set n 0
    foreach team $list {
	incr n
	
	if { $probs($team) == 0 } {
	    set rank 0
	} else {
	    set rank $n
	}
	
	
	if [ catch { set fx [ glob $contest/groups/*/$team ] } ] {
	    execute::report_error "undefined team" $team
	    continue
	} else {
	    set tm [ data::open $fx ]
	    set ${tm}::Rank $rank
	    data::record $fx
	}
    }    
}

## Show a cell in the classification table
proc short::cell {team problem} {
    variable Infinity
    variable points
    variable size
    variable attpt 

    if { $attpt($team,$problem) == 0 } {
	set status "&nbsp;"
    } elseif { $size($team,$problem) == $Infinity } {
	set status [ format {%s atts} $attpt($team,$problem) ]
    } else {
	set status [ format {%s bts / %s pts}		\
			 $size($team,$problem)		\
			 $points($team,$problem) ]
	
    }
    return $status
}

## Number of solved problems
## Does it make sense for SIZE?
proc short::solved {team} {
    variable probs

    return $probs($team)
}

## Total points for team
proc short::points {team} {
    variable points

    return  $points($team)
}

## Compares team's rank according to
##	1) number of points 
##	2) number of attempts
proc short::compare_points {a b} {
    variable points
    variable attpt 

    if { $points($a) == $points($b) } {
	return [ expr $attpt($a) < $attpt($b) ]
    } else {
	return [ expr $points($a) < $points($b) ]
    }
}
     
## Compares team's rank in problem according to
##	1) size of solution
##	2) time of solution
## Problems with size 0 (unsolved) are ignored
proc short::compare_sizes {problem a b} {
    variable size
    variable time

    if { $size($a,$problem) == $size($b,$problem) } {
	return [ expr $time($a,$problem) > $time($b,$problem) ]
    } else {
	return [ expr $size($a,$problem) > $size($b,$problem) ]
    }
}
     
