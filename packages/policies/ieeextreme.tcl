#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: ieeextreme.tcl
# 
## Marking and classification policies for IEEExtreme contests

package provide ieeextreme 1.0

package require utils

namespace eval ieeextreme {

    # points of penalty for wrong submissions (excluding CTE and PE)
    variable Points

    array set Points {
	"Accepted"		       100
	"Presentation Error"		90	
	"Wrong Answer"			-1
	"Output Limit Exceeded"		-1
	"Memory Limit Exceeded"		-1
	"Time Limit Exceeded"		-1
	"Invalid Function"		-1
	"Runtime Error"			-1
	"Compile Time Error"		 0
	"Invalid Submission"		-1
	"Program Size Exceeded"		-1
	"Requires Reevaluation"		 0
	"Evaluating"			 0
    }


    # variables used in ranking teams
    variable total
    variable probs
    variable attpt   
    variable durat

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
proc ieeextreme::subjective {} {
    return 0
}

## Sort teams by rank
proc ieeextreme::order {teams problems subs} {
    variable Points

    variable total
    variable probs
    variable attpt   
    variable durat
    variable resol

    upvar ::Submission::Results Results

    set accepted [ lindex $Results 0 ]

    # initialize
    foreach team $teams {
	set total($team) 0
	set probs($team) 0
	set attpt($team) 0
	foreach problem $problems {
	    set durat($team,$problem) ""
	    set attpt($team,$problem) 0
	    set penal($team,$problem) 0
	    set resol($team,$problem) 0
	    set total($team,$problem) 0
	}
    }

    # compute points
    foreach sub [ lsort $subs ] {

	if { ! [ Submissions::load_submission $sub ] } continue 

	if { [ lsearch $teams $Team ] == -1 } {
	    execute::record_error "Undefined team '$Team'"	
	    continue
	}
	# if already accepted ignore subsequent submissions
	if $resol($Team,$Problem) continue

	switch $Classify {
	    Accepted {
		incr total($Team) -$total($Team,$Problem)
		set  total($Team,$Problem) $Points($Classify)
		incr total($Team,$Problem) $penal($Team,$Problem)
		incr total($Team) $total($Team,$Problem)
		set resol($Team,$Problem) 1
		incr probs($Team) 
		set durat($Team,$Problem) [ date::from_long_sec $Time ]
	    }

	    "Presentation Error"  {
		incr attpt($Team,$Problem)
		if { $total($Team,$Problem) == 0 } {
		    set  total($Team,$Problem) $Points($Classify)
		    incr total($Team,$Problem) $penal($Team,$Problem)
		    incr total($Team) $total($Team,$Problem)
		    set durat($Team,$Problem) [ date::from_long_sec $Time ]
		}
	    }
	    default {
		if { [ string equal $durat($Team,$Problem) ""  ] } {
		    set durat($Team,$Problem) ------
		}
		incr attpt($Team)
		incr attpt($Team,$Problem)
		incr penal($Team,$Problem) $Points($Classify)
	    }
	}
    }

    return [ lsort -command ::ieeextreme::cmp_pont $teams ]
}

## Assign ranks to teams
proc ieeextreme::rank {contest list} {
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
proc ieeextreme::cell {team problem} {
    variable durat
    variable attpt 
    variable resol

    if { $durat($team,$problem) == "" } {
	set status "&nbsp;"
    } else {
	if $resol($team,$problem) {
	    set form {%s (%s)}
	} else {
	    set form {<i>%s</i> (%s)}
	}
	set status [format $form $durat($team,$problem) $attpt($team,$problem)]
	
    }
    return $status
}

## Number of solved problems
proc ieeextreme::solved {team} {
    variable probs

    return $probs($team)
}

## Total points for team
proc ieeextreme::points {team} {
    variable total

    return  $total($team)
}

# Compares team's rank according to
#	1) total points
#	2) number of solved problems
#	3) number of attempts
proc ieeextreme::cmp_pont {a b} {
    variable total
    variable probs
    variable attpt 


    if { $total($a) == $total($b) } {

	if { $probs($a) == $probs($b) } {
	    return [ expr $attpt($a) < $attpt($b) ]
	} else {
	    return [ expr $probs($a) < $probs($b) ]
	}	    

    } else {
	return [ expr $total($a) < $total($b)  ]
    } 
}
