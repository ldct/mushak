#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: icpc.tcl
# 
## Marking and classification policies for contests used in quizes
## Based on the exam policy

package provide quiz 1.0

package require utils

namespace eval quiz {

    # variables used in ranking teams
    variable marks

    variable groups
    variable group_id
    variable group_value

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
proc quiz::subjective {} {
    return 1
}

proc quiz::problems {dir} {
    variable groups
    variable group_id

    set path $dir/../quiz 
    set groups {}
    foreach group_dir [ glob -nocomplain -type d $path/* ] {
	set group [ file tail $group_dir ]
	if { [ string equal $group images ] } continue
	lappend groups $group
	set group_id($group) [ file::inode $group_dir ]

    }

    return [ lsort -command quiz::cmp_group_id $groups ]
}


## Sort teams by rank
proc quiz::order {teams problems subs} {
    variable marks
    variable groups
    variable group_id
    variable group_value

    # Quiz problem ID parked is "-"
    set problems "-"

    upvar ::Submission::Results Results

    set accepted [ lindex $Results 0 ]

    # initialize
    foreach team $teams {
	set marks($team) 0
	foreach problem $problems {
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
	
	set quiz [ file::read_in $sub/quiz.xml ]

	set ref {<quizGroup title="[^\"]*" xml:id="_%d" value="([^\"]*)">}
	foreach group $groups {
	    set re [ format $ref $group_id($group) ]	    
	    if { [ regexp $re $quiz - value ] } {
		set group_value($Team,$group) $value
	    }	    
	}

	if { $Mark > $marks($Team,$Problem) } {
	    set marks($Team,$Problem) $Mark
	}
    }

    # wrap up
    foreach team $teams {
	set marks($team) 0
	foreach problem $problems {
	    set marks($team) [ expr $marks($team) + $marks($team,$problem) ]
	}
    }

    return [ lsort -command ::quiz::cmp_pont $teams ]
}

## Assign ranks to teams
proc quiz::rank {contest list} {

    data::open $contest/groups

    set n 0
    foreach team $list {
	incr n
	
	set rank $n
		
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
proc quiz::cell {team problem} {
    variable group_value

    if { [ info exists group_value($team,$problem) ] } {
	set status [ format {%2.2f} $group_value($team,$problem) ]
    } else {
	set status "&nbsp;"
    }
	
    return $status
}

## Number of solved problems
proc quiz::solved {team} {

    return ""
}

## Total points for team
proc quiz::points {team} {
    variable marks

    return  [ format {%2.2f} $marks($team) ]
}

# Compares team's rank according to
#	1) total numer of points (marks)
proc quiz::cmp_pont {a b} {
    variable marks
    variable attpt 


    return [ expr $marks($a) < $marks($b) ]
}


#
# Compares group ids G1 G2 G20
proc quiz::cmp_group_id {a b} {

    if {
	[ regexp {0*(\d+)$} $a - ga ]  &&
	[ regexp {0*(\d+)$} $b - gb ] } {
	return [ expr $ga > $gb ]
    } else {
	return [ string compare $a $b ]
    }
}
