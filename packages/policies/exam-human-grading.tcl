#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: icpc.tcl
# 
## Marking and classification policy for contests used as exams.
## This policy is the same as the old "exam" policy
## This policy does NOT use automatic evaluation. 
## Judges must grade each submission individually.
## Total points is the some of points givem for each submission
## Number of solved problems is the number of problems with 
## submissions graded above 0 (not completly solved problems).


package provide exam-human-grading 1.0

package require utils

namespace eval exam-human-grading {

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
proc exam-human-grading::subjective {} {
    return 1
}

## Sort teams by rank
proc exam-human-grading::order {teams problems subs} {
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

	if { $Mark > $marks($Team,$Problem) } {
	    set marks($Team,$Problem) $Mark
	}
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

    return [ lsort -command ::exam-human-grading::cmp_pont $teams ]
}

## Assign ranks to teams
proc exam-human-grading::rank {contest list} {
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
proc exam-human-grading::cell {team problem} {
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
proc exam-human-grading::solved {team} {
    variable probs

    return $probs($team)
}

## Total points for team
proc exam-human-grading::points {team} {
    variable marks

    return  $marks($team)
}

# Compares team's rank according to
#	1) total numer of points (marks)
#	2) number of attempts
proc exam-human-grading::cmp_pont {a b} {
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