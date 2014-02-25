#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: icpc-incremental.tcl
# 
## Marking and classification policies for ICPC contests

package provide icpc-incremental 1.0

package require utils

namespace eval icpc-incremental {
    upvar ::Submission::Results Results

    variable Accepted [ lindex $Results 0 ]

    # time (in secs) of penalty for wrong submissions
    variable Penalty	[ expr 20 * 60 ]	

    variable CACHE_FILE icpc-incremental.tcl

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
proc icpc-incremental::subjective {} {
    return 0
}

## Sort teams by rank
proc icpc-incremental::order {teams problems subs} {
    variable Penalty
    variable Accepted

    variable total
    variable probs
    variable attpt   
    variable durat


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
	if { [ string compare $Classify $Accepted ] == 0 } {
	    incr probs($Team) 
	    incr total($Team) $Time 
	    incr total($Team) $penal($Team,$Problem)
	    set durat($Team,$Problem) [ date::from_long_sec $Time ]
	    set resol($Team,$Problem) 1
	} else {
	    set durat($Team,$Problem) ------
	    incr attpt($Team)
	    incr attpt($Team,$Problem)
	    incr penal($Team,$Problem) $Penalty
	}
    }

    return [ lsort -command ::icpc-incremental::cmp_pont $teams ]
}


## Sort teams by rank
proc icpc-incremental::incremental_order {dir teams problems limit} {
    package require cache

    variable total
    variable probs
    variable attpt   
    variable durat
    variable penal
    variable resol

    variable ::Session::Conf
    variable ::cache::CACHE_DIR_NAME
    variable CACHE_FILE

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
	}
    }
    
    set conf_teams $Conf(teams)
    foreach team_id $teams {
	
	set team_dir [ glob -type d -nocomplain $dir/../groups/*/$team_id ] 

	set cache_dir $team_dir/$CACHE_DIR_NAME
	file mkdir $cache_dir
	set cache_file $cache_dir/$CACHE_FILE
	
	if { ! [ cache::restore $cache_file ] } {

	    set Conf(teams) $team_id
	    set submissions  [ listing::restrict $dir ] 

	    if { $limit > -1 } {
		set submissions \
		    [ listing::older_submissions $submissions $limit ]
	    } 	

	    compute_points $submissions

	    set fd [ cache::reopen $cache_file ]

	    foreach var {total probs attpt} {
		set val  [ list [ set ${var}($team_id) ] ]
		puts $fd [ format {set %s(%s) %s} \
			       $var $team_id $val ]		
	    }	    
	    foreach problem $problems {
		
		foreach var {durat attpt penal resol} {
		    set val  [ list [ set ${var}($team_id,$problem) ] ]
		    puts $fd [ format {set %s(%s,%s) %s} \
				   $var $team_id $problem $val ]
		    
		}	    
	    }

	    cache::replace $fd
	}
    }
    set Conf(teams) $conf_teams 

    return [ lsort -command ::icpc-incremental::cmp_pont $teams ]
}


##
proc icpc-incremental::compute_points {subs} {
    variable Accepted
    variable Penalty

    variable total
    variable probs
    variable attpt   
    variable durat
    variable penal
    variable resol

    foreach sub [ lsort $subs ] {

	if { ! [ Submissions::load_submission $sub ] } continue 

	# if already accepted ignore subsequent submissions
	if $resol($Team,$Problem) continue
	if { [ string compare $Classify $Accepted ] == 0 } {
	    incr probs($Team) 
	    incr total($Team) $Time 
	    incr total($Team) $penal($Team,$Problem)
	    set durat($Team,$Problem) [ date::from_long_sec $Time ]
	    set resol($Team,$Problem) 1
	} else {
	    set durat($Team,$Problem) ------
	    incr attpt($Team)
	    incr attpt($Team,$Problem)
	    incr penal($Team,$Problem) $Penalty
	}
    }
}


## Assign ranks to teams
proc icpc-incremental::rank {contest list} {
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
proc icpc-incremental::cell {team problem} {
    variable durat
    variable attpt 

    if { $durat($team,$problem) == "" } {
	set status "&nbsp;"
    } else {
	set status [ format {%s (%s)}		\
		$durat($team,$problem)	\
		$attpt($team,$problem) ]
	
    }
    return $status
}

## Number of solved problems
proc icpc-incremental::solved {team} {
    variable probs

    return $probs($team)
}

## Total points for team
proc icpc-incremental::points {team} {
    variable total

    return  [ date::from_long_sec $total($team) ]
}

# Compares team's rank according to
#	1) number of solved problems
#	2) accumulated solving time (including penalties)
#	3) number of attempts
proc icpc-incremental::cmp_pont {a b} {
    variable total
    variable probs
    variable attpt 

    if { $probs($a) == $probs($b) } {
	if { $total($a) == $total($b) } {
	    return [ expr $attpt($a) < $attpt($b) ]
	} else {
	    return [ expr $total($a) > $total($b) ]
	}
    } else {
	return [ expr $probs($a) < $probs($b) ]
    }
	
}
