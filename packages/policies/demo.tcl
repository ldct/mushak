#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: demo.tcl
# 
## Marking and classification policies for generic contests (DEMO)

package provide demo 1.0

namespace eval demo {

    # variable used to rank teams
    variable Points 		;# points per problem and e team/problem
    variable Attempted		;# team/problem was attempted
    variable Problems		;# problems solved by team
    variable Weight		;# weigh of components in the classification

    array set Weight {
	style	0.5
	solution 0.5
    }

    # a policy MUST define these procedures
    # view this as a kiind of contact or interface
    namespace export subjective	;# is grading subjective?
    namespace export sort	;# sort teams by rank
    namespace export rank	;# assign ranks to teams
    namespace export cell	;# show a cell in the classification table
    namespace export solved	;# number of solved problems
    namespace export points	;# number of points per team
}

## Is grading subjective (a value given by a judge person)?
proc demo::subjective {} {
    return 1
}

# sort teams by rank
proc demo::order {teams problems subs} {
    variable Points
    variable Problems
    variable Weight
    variable Attempted

    upvar ::Submission::Results Results

    set accepted [ lindex $Results 0 ]

    # initialize
    foreach team $teams {
	set Points($team) 0
	set Problems($team) 0
	foreach problem $problems {
	    set Points($team,$problem) 0
	    set Problems($team,$problem) 0
	    set Attempted($team,$problem) 0
	}
    }

    # compute points
    foreach sub [ lsort $subs ] {

	if { ! [ Submissions::load_submission $sub ] } continue 

	if { [ lsearch $teams $Team ] == -1 } {
	    record "Undefined team '$Team'"
	    continue
	}

	set Attempted($Team,$Problem) 1
	if { [ string compare $Classify $accepted ] == 0 } {
	    set Problems($Team,$Problem) 1
	    set sol 100
	} else {
	    set sol 0
	}
	set p [expr ($Mark * $Weight(style) + $sol * $Weight(solution)) / 100]
	if { $p > $Points($Team,$Problem) } {
	    set Points($Team,$Problem) $p
	}
    }

    foreach team $teams {
	set Points($team) 0
	foreach problem $problems {
	    incr Problems($team) $Problems($team,$problem)
	    set Points($team) \
		    [ expr $Points($team) + $Points($team,$problem) ]
	}
    }

    return [ lsort -command demo::cmp_pont $teams ]
}

## Assign ranks to teams (INCOMPLETE)
proc demo::rank {contest list} {
    variable Problems

    set n 0
    foreach team $list {
	incr n
	
	if { $Problems($team) == 0 } {
	    set rank 0
	} else {
	    set rank $n
	}
	
	if { [ set fx [ data/contest/groups team $team ] ] == "" } {
	    execute::report_error "indefinida team '$team'"
	    continue
	} else {
	    set tm [ data::open $fx ]
	    set ${tm}::Rank $rank
	    data::record $fx
	}
    }    
}

## Show a cell in the classification table
proc demo::cell {team problem} {
    variable Points
    variable Attempted

    if { $Attempted($team,$problem)  } {
	set status $Points($team,$problem)
    } else {	
	set status "&nbsp;"
    }
    return $status
}

## Number of solved problems
proc demo::solved {team} {
    variable Problems

    return $Problems($team)
}

## Number of points per team
proc demo::points {team} {
    variable Points

    return  $Points($team)
}


## Compare team rank according to number or points
proc demo::cmp_pont {a b} {
    variable Points

    return [ expr $Points($a) < $Points($b) ]
	
}

