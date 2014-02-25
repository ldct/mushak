#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: contest.tcl
# 
## Utilities specific to Mooshak's contest management
##
## TODO: memory usage in time is not working properly

package provide contest 1.0

namespace eval contest {

    variable UsageFile		/var/tmp/usage	;## usage tmp file prefix
    variable UsageVars

    set UsageVars	{ elapsed cpu memory }

    namespace export active		;## Checks if there's an active contest
    namespace export active_path	;## Return path to active contest
    namespace export contest_name	;## Pathname to current contest
    namespace export with_team	    	;## Is a team defined in this request?
    namespace export team	    	;## Name of team in this request
    namespace export team_path	    	;## Pathname of team directoryx
    namespace export transaction	;## Creates a transaction dir
    namespace export transaction_time	;## Transaction creation time
    namespace export requires_reevaluation

}

## Checks if there is an active contest directory
proc contest::active {{report 1}} {
    variable ::Session::Conf
    
    if { [ info exists Conf(contest) ] && $Conf(contest) != "" } {
	return 1
    } else {
	if $report {
	    # layout::alert "No contest selected"
	    # template::load empty.html

	    template::load relogin.html ;# force login if no contest selected
	    template::write 
	    exit

	}
	return 0
    }
}

## Returns path to active contest, or null if none active
proc contest::active_path {} {
    variable ::Session::Conf
    
    return data/contests/$Conf(contest)

}

## Is there a team (i.e. user)?
proc contest::with_team {} {
    variable ::Session::Conf
    
    return [expr [ string equal $Conf(profile) team ] && \
		! [string equal $Conf(user) "" ] ]

}

## Returns the name of the team (in fact, the authenticated user).
proc contest::team {} {
    variable ::Session::Conf
    
    return $Conf(user)
}

# Returns path to current team or empty string 
proc contest::team_path {} {
    variable ::Session::Conf

    return [glob -nocomplain data/contests/$Conf(contest)/groups/*/$Conf(user)]
}


## Creates a transaction pathname of a given type indexed by problem and team
proc contest::transaction {type problem team} {
    variable ::Session::Conf
    
    set active data/contests/$Conf(contest)

    data::open $active

    set duration [ $active passed ]

    return [format {%s/%s/%08d_%s_%s} $active $type $duration $problem $team ]
}

## Returns transaction creation time as encoded in its pathname
proc contest::transaction_time {} {
    upvar _Self_ path

    return [ string trimleft [ lindex [ split [ file tail $path ] _ ] 0 ] 0 ]
}

## Detects suspicious messages related to system problems
## hopefully this watchdog is no longer needed now that a
## different user per request is being used
proc contest::requires_reevaluation {msg} {
    
    foreach pattern {
	"Resource temporarily unavailable"
	"virtual memory exhausted"
    } {
	if [ regexp $pattern $msg ] { return 1 }
    }
    return 0
}

## DEPRECATED
## Expand command line to allow reading usage 
## Command must be execute elsewhere
proc contest::expand_usage {command_line} {
    variable UsageFile
    variable Time
    variable TimeFormat

    set usage_file $UsageFile[pid]
    return "$command_line 2> $usage_file"

    ## safeexec is doing the role of time in collecting resource usage data
    #return "$Time -f '$TimeFormat' $command_line 2> $usage_file"

}

## Return usage filename
proc contest::usage_file {} {
   variable ::file::TMP

   return $TMP/usage-[pid]
}


##
proc contest::remove_usage_file {} {
    variable ::Language::SafeExec

    set usage_file [ usage_file ]
    
    if [ file exists $usage_file ] {
	set owner [ uid_file_owner $usage_file ]

	exec $SafeExec --uids $owner $owner --silent --exec /bin/rm -f $usage_file
    }
}

## Returns UID of file owner
proc contest::uid_file_owner {fx} {

    # if uid has an associated username (can happend), 
    # username (insted of uid) is returned
    # set fxuid [ file attributes $fx -owner ]	

    file stat $fx fxstats
    set fxuid $fxstats(uid)

    return $fxuid
}


## Parse the output of time: set  errorInfo and errorCode variables
## and set Usage array with apropriate values
proc contest::parse_usage {usage_} {
    global errorInfo
    global errorCode
    upvar $usage_ Usage
    variable UsageFile
    variable UsageVars 
    variable ComputedVars

    set usage_file [ usage_file ]

    if [ file readable $usage_file ] {
	set fd [ open $usage_file r ]

	gets $fd line

	if { [ regexp {^Command terminated by signal \((\d+): (\w*)\)} \
		   $line - errorCode errorInfo ] } {
	    # signal are converted in negative errorCodes
	    set errorCode -$errorCode
	} elseif { [ regexp {^Command exited with non-zero status \((\d+)\)} \
			 $line - errorCode ]
	       } {
	    # status are positive errorCodes
	} else {
	    # everything else just goes to errorInfo
	    append errorInfo $line
	}

	while { [ gets $fd line ] > -1 } {	    
	    foreach {var - value units} $line {}
	    set Usage($var) $value
	}
	catch { close $fd }
    }

    if { ! [ array exists Usage ] } {
	foreach var $UsageVars {
	    set Usage($var) -0.00
	}
    }	 

}
