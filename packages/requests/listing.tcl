#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#--------------------------------------------------------------------------
# file: listing.tcl
# 
## Major listings used and listing related procedures. 
## These listings aggregate transaction data (submissions, questions, etc)
## and the actual lines are computed in the related classes 
## (Submission, Question, etc). The procedures provided in this package deal
## with generic listing issues such us: 
## <ul>
##	<li>sorting lines </li>
## 	<li>breaking listings into pages</li>
##	<li>navigating in multi-page listings</li>
##	<li>resticting listings to certain problems or teams</li>
##</ul>
##
## These listings are used in all user profiles (teams, admin, judges) 
## There is a flag for hiding/showing sensitive information 
##
## TODO: make listings independent from active contest: define contest in state

package provide listing 1.0

namespace eval listing {
    
    #variable Conf		;## Configuration array
    variable Dir		;## Array with directories for listings

    namespace export state	;## Processes CGI state
    namespace export list	;## Produces a listing given by CGI variable
    namespace export define_vars;## Define CGI variables as local variables
    namespace export restrict	;## Returns list of transactions in a dir 
    namespace export part	;## Breaks a list in several pages
    namespace export cmp	;## Comparing transactions 

    # DEPRECATED
    array set Conf {
	type		submissions
	time		5
	page		0
	lines		15
	problems	{}
	teams		{}
    }	

    array set Dir {
	pending		{}
	submissions	submissions
	ranking		submissions
	evolution	submissions
	statistics	submissions
	questions	questions
	printouts	printouts
	balloons	balloons

	checks		../checks
	errors		../errors
    }
}

# Reset listing to first page
proc listing::reset {} {
    variable ::Session::Conf

    set Conf(page) 0
}

## Produces a listing parametrized by CGI data 
proc listing::listing {} {
    variable ::Session::Conf
    variable Dir
    global env


    if { [ contest::active [ set just_report 0 ] ] } {

	if { 
	    [ info exists env(HTTP_REFERER) ] &&
	    [ regexp {htools} $env(HTTP_REFERER) ] 
	} {

	    # listings requested from teams interface 
	    # have a special title window
	    team::request 						\
		$Conf(controller)?[ cgi::url_encode_state ]		\
		[ list [ string totitle [ cgi::field type ] ] ]
	} else {	

	    set path [ contest::active_path ]/$Dir($Conf(type))
	    data::open $path
	    
	    if { [ info tclversion ] < 8.6 } {
		$path $Conf(type) $Conf(profile)
	    } else {
		if { [ set content [ cache::start $path ] ] == {} } {

		    $path $Conf(type) $Conf(profile)

		    cache::stop
		} else {
		    puts -nonewline $content
		    flush stdout
		}
	    }
	}
    } else {
	# if no contest selected then produce an empty page
	template::load empty
	template::write
    }

}



## Define CGI variables as local variables is in calling procedure
proc listing::define_vars {} {
    variable ::Session::Conf

    foreach var [ array names Conf ] {
	upvar $var $var
	
	set $var $Conf($var)
    }
}


## Breaks a listing in several parts (pages) with a given number of lines
proc listing::part {list_ pages_ last_ line_} { 
    variable ::Session::Conf
    upvar $list_   list	
    upvar $pages_ pages
    upvar $last_  last 
    upvar $line_  line

    set last [ llength $list ]    

    if { ! [ regexp {^\d+$} $Conf(lines) ] } {
	set Conf(lines) $last
    }

    set list [ lrange $list 			\
	    [ expr $Conf(page) * $Conf(lines) ]		\
	    [ expr (($Conf(page)+1) * $Conf(lines))-1 ] ]
    set pages [ expr $last / $Conf(lines) + ($last % $Conf(lines)?1:0)]
    set line [ expr $last - $Conf(page) * $Conf(lines)  ]
}


## Returns list of transactions in a dir for selected problems and teams
proc listing::restrict {dir} {
    variable ::Session::Conf
    

    if { [ cgi::field all_teams {} ] != {} } {
	set Conf(teams) {}
    }

    if { [ cgi::field all_problems {} ] != {} } {
	set Conf(problems) {}
    }

    if { $Conf(problems) == {} } { 
	set problems * 
    } else { 
	set problems $Conf(problems) 
    } 

    if { $Conf(teams) == {} }    { 
	set teams    * 
    } else { 
	set teams $Conf(teams) 
    }

    set list {}
    foreach problem $problems {
	foreach team $teams {
	    set list [ concat $list \
		[ glob -type d -nocomplain $dir/*\[0-9\]_${problem}_${team}* ] ]
	    ## Final * allows more characters in submission pathname
	    ## In services several submission from the same team(requester)
	    ## and problem submisions can occur in the same second
	}
    }

    return $list
}

## Returns list of transactions in a dir for selected problems and teams
proc listing::unrestrict {dir} {
    return [ glob -type d -nocomplain $dir/*\[0-9\]_*_* ]
}

## return sub-list of submissions older than given date, unless from user
## TODO: optimize (careful, list may not be sorted !)
proc listing::older_submissions {list date {user ""} } {
    
    set new {}
    foreach sub $list {
	if { ! [regexp {/([0-9]+)_([^_]+)_(.*)$} $sub - sdate - suser] } continue
	set sdate [ string trimleft $sdate 0 ]
	if { $sdate <= $date } {
	    lappend new $sub
	} elseif { [ string equal $suser $user ] } {
	    lappend new $sub
	}
    }
    return $new
}

## Write listing header
proc listing::header args {
    variable ::Session::Conf
    
    set callingProc [ info level [ expr [ info level ] - 1 ] ] 
    if { ! [ regexp {::(.*?) } $callingProc - listingType ] } {
	set listingType ""
    }
    set title "Mooshak: $Conf(contest) $listingType"

    # load some extra vars from the calling procedure
    foreach var $args { upvar $var $var  }

    translate::labels country team problem problems \
	result language subject state points solved subject
    
    set help_button [ layout::help_button interface/listings/$Conf(type) ]

    foreach var {time time_type page lines type teams} { set $var $Conf($var) }

    set update [ expr $time * 60 ]

    set template listing
    if [ info exists Conf(format) ] {
	append template .$Conf(format)
    }

    template::load $template

    template::write pre 

    set time_selector [ layout::menu time_type \
			    {contest absolute relative} $time_type  \
			    [ translate::sentence_list {
				"Contest Time" 
				"Absolute Time" 
				"Relative Time"
			    } ] 1 "this.form.submit();" Header ]
    template::write [ string range $type 0 2 ]:head
}

## Write listing footer
proc listing::footer {n pages list {cols 0}} {
    variable ::Session::Conf


    # produces extra empty lines 
    set extra [ expr $Conf(lines) - [ llength $list ] ]
    if { $extra < 0 } { set extra 0 }
    incr n
    for { set i 0 } { $i < $extra } { incr i } {
	layout::toggle_color n color
	template::write empty
    }
    
    template::write mid    

    set page $Conf(page)
    
    set previous_fields 	page=[ expr $page - 1 ] 
    set next_fields		page=[ expr $page + 1 ] 

    if { [ set terms [ cgi::field terms "" ] ] != ""  } {
	set terms [ join $terms + ]
	append previous_fields &terms=$terms
	append next_fields &terms=$terms
    }


    incr page
    if { $page == 1 } { 
	template::write no_button
    } else { 
	template::write back_button
    }
    if { $pages > 0 } {
	template::write page_number
    }

    if { $page >= $pages } { 
	template::write no_button
    } else { 
	template::write forward_button
    }
    
    template::write foot listing
}

## Comparing transactions using a list of criteria containig REs
proc listing::cmp {C a b} {
    
    if { [ set c [ lindex $C 0 ] ] == "" } {
	return [ string compare $b $a ]
    } else {
	#test next criteria

	if { $a == "" || [ regexp $c $a ] } {
	    if { $b == "" || [ regexp $c $b ] } {
		cmp [ lrange $C 1 end ] $a $b 
	    } else {
		return -1 
	    }
	} else {
	    if { $b == "" || [ regexp $c $b ] } {
		return 1
	    } else {
		cmp [ lrange $C 1 end ] $a $b 
	    }
	}
    }
}
