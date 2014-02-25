#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: icpc.tcl
# 
## Marking and classification policies for IOI contests

package provide ioi 1.0

package require utils

namespace eval ioi {

    # variables used in ranking teams
    variable probs
    variable attpt   
    variable marks

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
proc ioi::subjective {} {
    return 1
}

## Sort teams by rank
proc ioi::order {teams problems subs} {
    variable probs
    variable attpt   
    variable marks

    upvar ::Submission::Results Results

    set accepted [ lindex $Results 0 ]

    # initialize
    foreach team $teams {
	set attpt($team) 0
	set marks($team) 0
	foreach problem $problems {
	    set attpt($team,$problem) 0
	    set marks($team,$problem) 0
	}
    }

    # compute points
    foreach sub [ lsort $subs ] {

	if { ! [ Submissions::load_submission $sub ] } continue 

	if { [ lsearch $teams $Team ] == -1 } {
	    execute::record_error "Undefined team '$Team'"	
	    continue
	}

	incr attpt($Team)
	incr attpt($Team,$Problem)

	set marks($Team,$Problem) $Mark
    }

    # wrap up
    foreach team $teams {
	set marks($team) 0
	set probs($team) 0
	foreach problem $problems {
	    incr marks($team) $marks($team,$problem)
	    if { $marks($team,$problem) > 0 } {
		incr probs($team)
	    }
	}
    }

    return [ lsort -command ::ioi::cmp_pont $teams ]
}

## Assign ranks to teams
proc ioi::rank {contest list} {
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
proc ioi::cell {team problem} {
    variable marks
    variable attpt 

    if { $attpt($team,$problem) == 0 } {
	set status "&nbsp;"
    } else {
	set status [ format {%s (%s)}		\
			 $marks($team,$problem)	\
			 $attpt($team,$problem) ]
	
    }
    return $status
}

## Number of solved problems
## Does it make sense for IOI
proc ioi::solved {team} {
    variable probs

    return ""
}

## Total points for team
proc ioi::points {team} {
    variable marks

    return  $marks($team)
}


# Compares team's rank according to
#	1) total numer of points (marks)
#	2) number of attempts
proc ioi::cmp_pont {a b} {
    variable marks
    variable attpt 

    if { $marks($a) == $marks($b) } {
	if { $attpt($a) == 0 } {
	    return 1
	} elseif { $attpt($b) == 0 } {
	    return -1
	} else {
	    return [ expr $attpt($a) > $attpt($b) ]
	}
    } else {
	return [ expr $marks($a) < $marks($b) ]
    }
}