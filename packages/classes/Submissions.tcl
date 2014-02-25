#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Submissions.tcl
# 
## Set of de submissions (runs) during a contest
## and operations on that set, such as listings
## (history, ranking, statistics, etc ). These listings are similar for 
## all user profiles (admin, judge, team) but with some differences. The
## <code>profile<code> flag controles it.
##
## This package includes operations to replay the contest at different paces.
##
## TODO: show synthetic report to teams/students

package provide Submissions 1.0

namespace eval Submissions {
    variable MaxLabelSize 35	        ;## Truncate larger team names
    variable Stretch	8		;# Bar stretch in evolution listings
    variable Max_delay  5		;# Maximum delay (sec) in paced subs.
    variable Max_pipes  100		;# Max number of open pipes im replay
    variable Hold	1		;# Hold this time (sec) if $Max_Pipes
    variable Feedback_categories	;# Feedback categories
    

    set  Feedback_categories {
	none 
	classification 
	report
	all
    }

    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Default_state	"Default submission state when received"
	Multiple_accepts "Allow resubmissions of already accepted problems"
	Run_all_tests	"Run all test even if program is consuming too much resources (ex: time, memory)"
	Give_feedback	"Detail of feedback given to teams/students"
	Show_own_code   "Show the code they submitted to each team"
	Feedback_delay  "Minutes before showing a different feedback for the same error"
	Show_errors	"Show error messages/reports for these error types"
	Minimum_interval "Number of seconds between submissions of same team"
	Maximum_pending	"Maximum number of submissions waiting for validation (blocks new submissions)"
    }

    array set Help {
	Give_feedback "
Use this field to control the amount of feedback given to teams/students,
and select:

        none               to give minimal feedback (Received)
        classification  to show classification and errors messages *
        report             to show classification and feedback reports *
        all                    all information available to judges

* Error messages and reports are associated with errors selected in Show errors
"

	Show_errors "
When giving feedback use this selector to specify the type of errors
that will receive feedback
	"
	Feedback_delay "
Time, in seconds, between two different incremental reports
"
    }

}

# WORKAROUND: keeping pckIndex happy!
namespace eval Submission {}
if { ! [ info exists Submission::States ] } {
    set Submission::States {}
}
if { ! [ info exists ::Submission::Results ] } {
    set ::Submission::Results {}
}


#------------------------------------------------------------------------------
#     Class definition


Attributes Submissions 							\
    [ list								\
	  Fatal			fatal	{}				\
	  Warning		warning {}				\
									\
	  Default_state		menu 	[ Submission::get_states ]	\
	  Multiple_accepts	menu	{yes no}			\
	  Run_all_tests		menu	{yes no}			\
	  Show_own_code		menu	{yes no}			\
	  Give_feedback		menu	$::Submissions::Feedback_categories \
	  Show_errors		list    $::Submission::Results		\
	  Feedback_delay	text	{}				\
	  Minimum_interval	text	{}				\
	  Maximum_pending	text	{}				\
	  Submission		dirs	Submission			\
	 ]


Operation Submissions::_update_ {} {
    check::reset Fatal Warning

    foreach attr { Feedback_delay Minimum_interval Maximum_pending } {
	check::attribute Fatal $attr {^[0-9]*$}
    }

    if { 
	$Give_feedback != ""		&& 
	$Give_feedback != "none"	&& 
	$Show_errors == {} 
    } {
	check::record Warning simple \
	    "Select errors to show when giving feedback"
    }

    if { $Show_errors != {} 		&& 
	 ($Give_feedback == "" || $Give_feedback == "none")
     } {
	check::record Warning simple "Select a feedback type to show errors"	
    }


    return [ check::requires_propagation $Fatal ]    
}


## DEPRECATED?
## Checks if directory is empty
Operation Submissions::check {} {
    check::dir_start 
    check::dir_empty
    check::dir_end

}


## Cleans transactions in current directory as part of preparation
Operation Submissions::prepare {} {
    check::clear 
} 


## Run all test even if program is consuming too much resources (ex: time)
Operation Submissions::run_all_tests {} {
    if { 
	[ info exists Run_all_tests ] && 
	[ string equal $Run_all_tests "no" ]
    } {
	return 0
    } else {
	return 1
    }
} 

## Run all test even if program is consuming too much resources (ex: time)
Operation Submissions::show_own_code {} {
    if { 
	[ info exists Show_own_code ] && 
	[ string equal $Show_own_code "no" ]
    } {
	return 0
    } else {
	return 1
    }
} 


# DEPRECATED !?
## Give feedback to student/team?
# Operation Submissions::give_feedback {} {
#     if { 
# 	[ info exists Give_feedback ]
#     } {
# 	return $Give_feedback
#     } else {
# 	return "none"
#     }
# } 

# DEPRECATED !?
## Number of minutes before changing feedback
#Operation Submissions::feedback_delay {} {
#    if { 
#	[ info exists Feedback_delay ] &&
#	[ regexp {\d+} $Feedback_delay ]
#    } {
#	return $Feedback_delay
#    } else {
#	return 0
#    }
#}

## Returns observations based on current definitions and summary info
## Give_feedback defaulys to "classification" 
## in which case is given default feedback
Operation Submissions::get_observations {summary_info} {

    switch $Give_feedback {
	none - report {
	    return ""
	}
	default - classification		{ 
	    return [ layout::remove_html_tags \
			 [ feedback::default_summary $summary_info ] ]
	}
    }
}


## Returns feedback based on current definitions and summary info
Operation Submissions::get_feedback {problem team summary_info} {
    
    switch $Give_feedback {
	default - none	- classification {
	    return ""
	}
	report		{ 
	    return [ feedback::summarize ${_Self_} $problem $team $summary_info 				]
	}
    }
}



## Checks if this feedback message is fresh enough 
## i.i. it was never used before for this problem or not not long ago
Operation Submissions::fresh_feedback {team problem feedback} {
    variable ::Session::Conf

    if { 
	[ info exists Feedback_delay ] &&
	[ regexp {\d+} $Feedback_delay ]
    } {
	set delay $Feedback_delay
    } else {
	set delay 0
    }

    set active data/contests/$Conf(contest)

    data::open $active
    
    set now [ $active passed ]

    foreach fb [ glob -type d -nocomplain ${_Self_}/*_${problem}_${team}* ] {
	if [ catch {
	    set seg [ data::open $fb ]
	} ] continue
	
	variable ${seg}::Feedback
	variable ${seg}::Time
	if { [ info exists Feedback ]			&& 
	     [ string equal $Feedback $feedback ]	&&
	     [ info exists Time ]			&&
	     $Time + (60 * $delay) < $now 
	 } {
		return 0
	}
    }
    
    return 1
}

## Checks if a submission is acceptable for this team/problem
## It may not be acceptable if, for this problem and team:
## 1) there was a submission less than Minimum_interval seconds ago
## 2) the submited file is exactly the same as the previous one
## 3) a previous submission has been accepted as solution 
##    and the Multiple_accepts field has not been set
## 4) there are more than Maximum_pending submissions waiting to be validated 
Operation Submissions::acceptable {team {problem "-"}} {
    upvar ::Submission::Results Results
    variable ::file::TMP

    set candidate $TMP/[ cgi::field program {} ]
    set accepted  [ lindex $Submission::Results 0 ]
    set date	  [ clock seconds ]
    set pending	  0
    set message	  ""

    foreach sub [ glob -type d -nocomplain ${_Self_}/*_${problem}_${team}* ] {
	if [ catch {
	    set seg [ data::open $sub ]
	} ] continue
	## 1) there was a submission less than Minimum_interval seconds ago
	variable ${seg}::Date
	if {
	    [ info exists Minimum_interval ] 		&&
	    [ regexp {^[0-9]+$} $Minimum_interval ]	&&
	    $date - $Date < $Minimum_interval 
	} {
	    set message [  list "Too frequent submissions" ]
	    break
	}
	## 2) the submited file is exactly the same as to the previous one
	variable ${seg}::Size
	variable ${seg}::Program
	if { $candidate != {} } {
	    set size 	  [ file size $candidate ]
	    if {
		$size == $Size 				&& 
		[ compare::diff $candidate $sub/$Program ] == ""	    
	    } {
		set message [  list "Duplicate submission" ]
		break
	    }
	}

	set seg [ data::open $sub ]
	## 3) a previous submission has been accepted as solution 
	variable ${seg}::Classify
	if { 
	    [ string compare  $accepted  $Classify ] == 0 	&&
	    ! ( [ info exists Multiple_accepts ] 		&& 
		[ string equal $Multiple_accepts yes ] )
	} {
	    set problem_name ""
	    if { ! [ string equal $problem "-" ] } {
		catch {
		    set prob [ data::open ${_Self_}/../problems/$problem ]
		    set problem_name [ set ${prob}::Name ]
		}
	    }
	    set message [ list [ format "Problem %s already accepted" \
				     $problem_name ] ]
	    break
	}	

	variable ${seg}::State
	if [ string equal $State "pending" ] {
	    incr pending
	}
    }

    ## 4) more than Maximum_pending submissions waiting to be validated 
    if { 
	[ info exists Maximum_pending 		] 	&&
	[ regexp {^[0-9]+} $Maximum_pending	]	&&
	$pending > $Maximum_pending
    } {
	set message [ list "Too many peding submissions" ]
	lappend message [ list  (maximum=$Maximum_pending) ]
    }

    return $message

}


## Produces an evolution listing based on profile
Operation Submissions::evolution {{profile admin}} {
    variable ::Submission::Results
    variable ::Session::Conf
    variable Stretch

    foreach var {teams problems} { set $var $Conf($var) }

    set ACCEPTED [ lindex $Results 0 ]
    set contest  [ contest::active_path ]
    set message ""

    data::open $contest/groups
    if { $teams == "" } { 
	set teams  [ $contest/groups team_ids ] 
    }

    data::open $contest/problems
    if { $problems == "" } { 
	set problems [ $contest/problems problems [ set sorted 1 ] ]
    }

    set last -1

    data::open $contest

    # process submissions
    set submissions [ listing::restrict ${_Self_} ]
    if { [ set limit [ $contest hide_listings message ] ] > -1 } {
	set submissions [ listing::older_submissions $submissions $limit ]
    } 
    foreach sub $submissions  {

	if { ! [ load_submission $sub ] } continue 

	if { [ set line [ expr $Time / $Conf(time_interval) ] ] > $last } {
	    set last $line
	}

	if { [ string compare $Classify $ACCEPTED ] == 0 } {
	    etc::increment accepted($line,$Problem)
	} else {
	    etc::increment refused($line,$Problem)
	}
	
    }

    # process questions
    set question_list [ listing::restrict \
		      [file::canonical_pathname ${_Self_}/../questions ] ]
    if { $limit > -1 } {
	set question_list [ listing::older_submissions $question_list $limit ]
    }
    foreach per $question_list {

	set sp [ data::open $per ]

	set Time	[ set ${sp}::Time ]
	set Problem	[ set ${sp}::Problem ]
	
	if { [ set line [ expr $Time / $Conf(time_interval) ] ] > $last } {
	    set last $line
	}

	etc::increment questions($line,$Problem)
    }

    set list {}
    for { set line 0 } { $line <= $last } { incr line } {
	lappend list $line
    }

    listing::part list pages last n

    set nprob [ llength $problems ]

    set interval_selector [ mk_interval_selector ]

    listing::header nprob Stretch message interval_selector

    foreach problem $problems {
	set prob [ data::open $contest/problems/$problem ]
	set problem_name [ set ${prob}::Name ]
	set problem_color [ set ${prob}::Color ]
	template::write evo:head_problem
    }
    template::write evo:end_head

    foreach line $list {

	set time [ date::from_long_sec [ expr $line * $Conf(time_interval) ] ]

	layout::toggle_color n color
	
	template::write evo:line
	foreach problem $problems {
	
	    template::write evo:line_problem
	    foreach {a color} { accepted green refused red questions blue } {
		if [ info exists ${a}($line,$problem)  ] { 
		    set value [ set ${a}($line,$problem) ]
		    set stretch [ expr $value * $Stretch ]
		    template::write evo:value
		} else {
		    template::write evo:empty
		}
	    }
	    template::write evo:end_problem
	}
	template::write evo:end_line

    }
    listing::footer [ incr n ] $pages $list [ expr [llength $problems] + 1 ]
}


## Listing with contest statistics
Operation Submissions::statistics {{profile admin}} {
    variable ::Submission::Results
    variable ::Session::Conf

    foreach var {teams problems} { set $var $Conf($var) }
    set contest [ contest::active_path ]
    set message ""

    data::open $contest/groups
    if { $teams == "" } {
	set teams  [ $contest/groups team_ids ]
    }

    data::open $contest/problems
    if { $problems == "" } {
	set problems [ $contest/problems problems [ set sorted 1 ] ]
    }

    set last -1

    data::open $contest
    set submissions [ listing::restrict ${_Self_} ]
    if { [ set limit [ $contest hide_listings message ] ] > -1 } {
	set submissions [ listing::older_submissions $submissions $limit ]
    } 

    # process submissions
    foreach sub $submissions  {

	if { ! [ load_submission $sub ] } continue 

	etc::increment nsub($Classify,$Problem)	
	etc::increment nsub($Classify,Total)	
	etc::increment nsub(Total,$Problem)	
	etc::increment nsub(Total,Total)	
    }

    set list $Results
    lappend list Total
    if [ info exists nsub(Total,Total) ] {
	set all $nsub(Total,Total)
    }

    listing::part list pages last n

    set nprob [ llength $problems ]

    listing::header nprob Stretch message

    foreach problem $problems {
	set prob [ data::open $contest/problems/$problem ]
	set problem_name  [ set ${prob}::Name  ]
	set problem_color [ set ${prob}::Color ]
	template::write sta:head_problem
    }
    template::write sta:end_cab

    set res_color green
    foreach result $list {

	if [ string equal $result Total ] { set res_color black }

	layout::toggle_color n color
	template::write sta:result
	set perc 0
	foreach line { value perc } {
	    foreach problem $problems {
		template::write sta:result_problem
		if [ info exists nsub($result,$problem)  ] { 
		    set value $nsub($result,$problem)
		    if $perc {
			set value  [ format <i>%2.1f%%</i> \
				[ expr $value * 100 / $all.0 ] ]
		    }
		    template::write sta:value		
		} else {
		    template::write sta:empty
		}
		template::write sta:end_problem
	    }

	    if [ info exists nsub($result,Total) ] {
		set total $nsub($result,Total)
		if $perc {
		    set total  [ format <i>%2.1f%%</i> \
			    [ expr $total *100 / $all.0 ] ] 
		}
	    } else {
		set total "&nbsp;"
	    }
	    template::write sta:end_result
	    if { ! $perc } {
		set perc 1
		layout::toggle_color n color
		template::write sta:percent
	    }
	}
	set res_color red
    }

    listing::footer [ incr n ] $pages $list  [expr [llength $problems]+2]
}


Operation Submissions::export:ranking-tsv ? {
    export ranking tsv
}

Operation Submissions::export:submissions-tsv ? {
    export submissions tsv
}

Operation Submissions::export:ranking-xml ? {
    export ranking xml
}

Operation Submissions::export:submissions-xml ? {
    export submissions xml
}

proc Submissions::export {type format} {
    variable ::Session::Conf

    set backup [ array get Conf ]

    set Conf(type)	$type
    set Conf(format) 	$format
    set Conf(page)	0
    set Conf(lines)	all
    set Conf(problems)	{}
    set Conf(teams)	{}

    listing::listing

    array set Conf $backup
}

Operation Submissions::export:final ! {
    variable ::Session::Conf
    variable FinalFiles

    set index final.html
    set archive final.tgz

    set fd [ ::open ${_Self_}/$index w ]
    puts $fd [ ${_Self_} final ]
    ::close $fd

    set command [ file::archive_command $archive ] 

    set here [ pwd ]
    cd ${_Self_}
    if [ catch { 
	eval exec $command $archive $index $FinalFiles
    } msg ] {
	cd $here
	layout::alert $msg
    } 
    cd $here

    layout::window_close_after_waiting
    layout::window_open $Conf(controller)/${_Self_}/$archive
    
}

Operation Submissions::final {} {
    set contest [ contest::active_path ]
    data::open $contest
    data::open $contest/groups
    data::open $contest/problems

    set problems [ $contest/problems problems [ set sorted 1 ] ]

    set list [ lsort -decreasing [ listing::restrict ${_Self_} ] ]

    foreach sub_dir $list {
	if [ catch {  set sub [ data::open $sub_dir ] } msg ] { }
	    
	variable ${sub}::Team
	variable ${sub}::Classify
	variable ${sub}::Program
	variable ${sub}::Problem

	if { ! [ info exists name($Team) ] } {
	    # first time this team occurs
	    if { $problems == {} } {
		# this is a Quiz
		set accepted($Team,-) 0
	    } else {
		foreach problem $problems {
		    set accepted($Team,$problem) 0
		}
	    }

	    foreach {group_acronym team_name} \
		[ $contest/groups identify $Team {Acronym} {Name} ] {}
	    
	    set name($Team)    $team_name
	    set acronym($Team) $group_acronym

	}
	     
	if { $accepted($Team,$Problem) } continue
	     

	if [ string equal Classify 0 ] {
	    set program($Team,$Problem) [ file tail $sub_dir ]/$Program
	    set accepted($Team,$Problem) 1
	} else {
	    set accepted($Team,$Problem) 0	  
	    if { ! [ file exists program($Team,$Problem) ] } {
		set program($Team,$Problem) [ file tail $sub_dir ]/$Program
	    }
	}
    }

    variable FinalFiles {}

    set html "<html><head><title>Final submissions</title></head>"
    append html "<body><h1>Final submissions</h1>"

    foreach problem $problems {

	append html "<h2>$problem</h2>"
	append html "<ol>"
	foreach team [ lsort [ array names name ] ] {
	    if { ! [ info exist  program($team,$problem) ] } continue
	    lappend FinalFiles $program($team,$problem)
	    append html [ format {<li><a href="%s">%s</a> %s</li>} \
			      $program($team,$problem) \
			      $name($team) $acronym($team) ]
	}
	append html "</ol>"	
    }
    append html "</body></html>"
    return $html
}


## Listing of teams by rank
Operation Submissions::ranking {{profile admin} {record 0}} {
    variable ::Session::Conf
    variable MaxLabelSize

    set contest [ contest::active_path ]
    data::open $contest

    data::open $contest/groups

    set limit [ $contest hide_listings message ]
    set policy [ $contest policy ]


    if { $Conf(teams) == "" } {
	set teams  [ $contest/groups team_ids ]
    } else {
	set teams $Conf(teams)
    }

    if { 
	$Conf(problems) != {} || $limit > 1 ||
	[ string equal [ info procs ::${policy}::incremental_order ] "" ] 
    } {

	#non incremental (traditional) ranking of teams

	set submissions 	       [ listing::restrict ${_Self_} ] 

	if { $limit > -1 } {
	    set submissions [ listing::older_submissions $submissions $limit ]
	} 	

	set problems [ ranking_header $policy $contest ${_Self_} $message ]

	set sorted_teams [ ${policy}::order $teams $problems $submissions ]

    } else {
	# incremental ranking of teams - reuses previously computed data
	# cannot be used if problems where restricted 

	set problems [ ranking_header $policy $contest ${_Self_} $message ]

	set sorted_teams [ ${policy}::incremental_order ${_Self_} \
			       $teams $problems $limit ]
    }
	
    if $record {
	${policy}::rank $contest $sorted_teams
	return
    }

    
    listing::part sorted_teams pages last -

    set n [ expr $Conf(page) * $Conf(lines) ]
    foreach team $sorted_teams {
	layout::toggle_color n color
	foreach {group_color group_flag group_acronym team_name} \
	    [ $contest/groups identify $team {Color Flag Acronym} {Name}] {}

	set team_name [ layout::fit_label $team_name $MaxLabelSize ]

	template::write ran:team
	foreach problem $problems {
	    
	    set status [ ${policy}::cell $team $problem ]
	    template::write ran:team_problem
	    
	}
	set problems_total [ ${policy}::solved $team ]
	set total_time [ ${policy}::points $team ]
	
	template::write ran:end_team
    }

    listing::footer [ incr n ] $pages $sorted_teams \
	[ expr [llength $problems] + 6 ]
}



proc Submissions::ranking_header {policy contest dir message} {
    variable ::Session::Conf

    set problems $Conf(problems)

    data::open $contest/problems
    if { $problems == "" } {
	set problems [ $contest/problems problems [ set sorted 1 ] ]
    }

    if { 
	[ llength $problems ] == 0 && 
	[ info procs ::${policy}::problems ] != "" 
    }  {
	## if no problems were defined give the policy a chance to do it
	set problems [ ::${policy}::problems $dir ]
	set standard_problems 0
    } else {
	set standard_problems 1
    }


    set nprob [ llength $problems ]
    listing::header nprob message

    if $standard_problems {
	
	foreach problem $problems {
	    set prob [ data::open $contest/problems/$problem ]
	    foreach {v a d} {problem_name Name ? problem_color Color black} {
		if [ info exists ${prob}::${a} ] {
		    set $v [ set ${prob}::${a} ]
		} else {
		    set $v $d
		}
	    }	    
	    template::write ran:head_problem
	}

    } else {
	foreach problem $problems {
	    set problem_name $problem
	    set problem_color black
	    template::write ran:head_problem
	}
    }
    template::write ran:end_head

    return $problems
}



## Listing of submissions in reverse chronological order
Operation Submissions::submissions {{profile guest}} {

    set contest [ contest::active_path ]
    data::open $contest

    set list     [ lsort -decreasing [ listing::restrict ${_Self_}   ] ]
    set all_subs [ lsort -decreasing [ listing::unrestrict ${_Self_} ] ]
    set n_subs   [ llength $all_subs ]

    if { [ set limit [ $contest hide_listings message $profile ] ] > -1 } {
	variable ::Session::Conf

	set list [ listing::older_submissions $list $limit $Conf(user) ]
    }


    listing::header message

    listing::part list pages last n

    set show_own_code [ ${_Self_}  show_own_code ]

    # give classification feedback to admin and judges 
    # and just the selected level to teams and others
    if  [ regexp {^admin|judge$} $profile ] {
	set give_feedback classification
	set show_errors $::Submission::Results
    } else {
	foreach {field default} { 
	    Give_feedback		classification 
	    Show_errors			{}
	} {
	    set var [ string tolower $field ]
	    if [ info exists $field ] {
		set $var [ set $field ]
	    } else {
		set $var $default
	    }
	}
    }

    foreach sub $list {
	if [ catch {
	    set m [ expr $n_subs - [ lsearch $all_subs $sub ] ]
	    data::open $sub
	    $sub listing_line $m $n $profile $give_feedback $show_errors \
		$show_own_code
	} msg ] {
	    incr n

	    # puts <pre>$msg</pre>
	    # DONT SHOW CORRUPTED LINES
	    #set m $n
	    #layout::toggle_color m color
	    #template::write empty
	}
	incr n -1
    }

    listing::footer [ incr n ] $pages $list

}



Operation Submissions::Mining:all ? {

    puts {<pre>}
    print_header 
    data4mining::extract ${_Self_} 
    puts {</pre>}
}


#------------------------------------------------------------------------------
# Replay

## Replays submissions at the same pace they where submited (with delays)
Operation Submissions::Replay:paced ? {
    variable Fd
    variable Max_delay
    variable Subs

    Session::close 0	;# close session immediately

    replay_listing_header "Paced replay" \
	"Replays submissions at the same pace they where submited (with delays), but with a maximum time between submissions of $Max_delay seconds"

    set n 0
    set start [ clock seconds ]
    set Subs [ lsort [ glob -type d -nocomplain ${_Self_}/* ] ] 
    pace $start 0

    wait4processes
    
    replay_listing_footer
}

## Processes list of submissions with a maximum interval of $Max_delay
## reproducing the pace of the contest
proc Submissions::pace {start n} {
    variable Subs
    variable Max_delay
    variable Max_pipes
    variable Hold

    Session::close 0	;# close session immediately

    if { [ llength [ file channels ] ] > $Max_pipes } {
	# too many open pipes: try later
	after [ expr $Hold * 1000 ]  [ list Submissions::pace $start $n ]
	return
    }

    delegate_execute [ incr n ] [ lindex $Subs 0 ]
    set Subs [ lrange $Subs 1 end ]
    if { [ regexp {/0*([1-9][0-9]*)_[^/]+$} [ lindex $Subs 0 ] - time ] } {
	set delay [ expr $time - ([ clock seconds ] - $start) ]
	set mydelay [ expr $delay > $Max_delay ? $Max_delay : $delay ]
	if { $mydelay > 0 } { after [ expr $mydelay * 1000 ] }
	after $mydelay [ list Submissions::pace $start $n ]
    }

}


## Reevaluates all submissions sequentially, classifcations ARE changed
Operation Submissions::Reeval:all ? {

    Session::close 0	;# close session immediately

    replay_listing_header "Reevaluates <b>all</b> contest's submissions" \
	"Changing classifications will be updated"
    set n 0
    foreach sd [ lsort [ glob -type d -nocomplain ${_Self_}/* ] ] {
	execute [ incr n ] $sd 1 1
    }

    replay_listing_footer    

}

## Select submissions by problems to reevaluate, classifcations ARE changed
Operation Submissions::Reeval:by_problem ? {

    set problems ${_Self_}/../problems

    data::open $problems
	
    set selector [ $problems selector_list ]

    ${_Self_} reeval_some by_problem Problem problem $selector
}

## Select submissions by problems to reevaluate, classifcations ARE changed
Operation Submissions::Reeval:by_classify ? {


    set selector [ layout::menu classify $Submission::Results {} ]

    ${_Self_} reeval_some by_classify Classify classify $selector
}


## Select submissions by language to reevaluate, classifcations ARE changed
Operation Submissions::Reeval:by_language ? {

    set languages ${_Self_}/../languages

    data::open $languages
	
    set values  {}
    set texts   {}
    foreach lang [ $languages all ] {
    
	lappend values [ file tail $lang ]
	set lg [ data::open $lang ]
	lappend texts [ set ${lg}::Name ]
    }

    set selector [ layout::menu language $values {} $texts ]


    ${_Self_} reeval_some by_language Language language $selector
}




## Reevaluates some submissions, classifcations ARE changed
Operation Submissions::reeval_some {criteria label field selector} {

    set value  [ cgi::field $field "" ]

    if { $value == "" } {
	set dir ${_Self_}

	template::load Submissions/reeval_some.html
	
	template::write

    } else {
	Session::close 0	;# close session immediately
	
	replay_listing_header "Reevaluating submissions for $field '$value'" \
	    "Changing classifications will be updated"
	set n 0
	foreach sd [ lsort [ glob -type d -nocomplain ${_Self_}/* ] ] {

	    set so [ data::open $sd ]
	    
	    if { [ string equal [ set ${so}::$label ] $value ] } {
		
		execute [ incr n ] $sd 1 1
	    }
	    
	    data::close $sd
	}

	replay_listing_footer
    }
}



## Replays the submissions sequentially (no delays)
Operation Submissions::Replay:sequential ? {

    Session::close 0	;# close session immediately

    replay_listing_header "Sequential replay" \
	"Replays the contest's submissions sequentially (no delays)"
    set n 0
    foreach sd [ lsort [ glob -type d -nocomplain ${_Self_}/* ] ] {
	execute [ incr n ] $sd 1
    }

    replay_listing_footer    
}

## Replays all submissions eagerly, i.e. without waiting 
Operation Submissions::Replay:eager ? {
    variable Max_pipes
    variable Hold
    variable Subs

    replay_listing_header "Eager replay" \
	"Replays all submissions eagerly, without waiting"

    set n 0
    set Subs [ lsort [ glob -type d -nocomplain ${_Self_}/* ] ] 
    eager 0

    wait4processes
    
    replay_listing_footer
}

## Processes list of submissions with no maximum interval
proc Submissions::eager {n} {
    variable Subs
    variable Max_delay
    variable Max_pipes
    variable Hold

    if { [ llength [ file channels ] ] > $Max_pipes } {
	# too many open pipes: try later
	after [ expr $Hold * 1000 ]  [ list Submissions::eager $n ]
	return
    }

    delegate_execute [ incr n ] [ lindex $Subs 0 ]
    set Subs [ lrange $Subs 1 end ]

    if { [ regexp {/0*([1-9][0-9]*)_[^/]+$} [ lindex $Subs 0 ] - time ] } {
	after idle [ list Submissions::eager $n ]
    }
}



#------------------------------------------------------------------------------
# Procedures

## 
proc Submissions::replay_listing_header {title message} {
    variable Replay_start_time
    variable Replay_total_submissions
    variable Replay_changed_submissions
    variable Line_counter

    puts [ format {<h2>%s</h2>} $title ]
    puts [ format {<p>%s</p>} $message ]

    set Replay_total_submissions 0
    set Replay_changed_submissions 0

    set Replay_start_time [ clock seconds ]
    puts [ format {Started: %s} [ clock format $Replay_start_time ] ]

    puts [ format {<pre><b>%4s %-35s %-5s %-25s %-25s</b>} \
	       Seq Submission Lang Before After ]

    set Line_counter 0
}

proc Submissions::replay_listing_footer {} {
    variable Replay_start_time
    variable Replay_total_submissions
    variable Replay_changed_submissions

    set end_time [ clock seconds ]
    set duration [ expr $end_time - $Replay_start_time ]

    puts {</pre>}
    puts [ format {Concluded: %s<br>} [ clock format $end_time ] ]
    puts [ format {Duration : %s sec<br>} $duration ]
    puts [ format {Total submissions: %s<br>} $Replay_total_submissions ]


    if { $Replay_total_submissions == 0 } {
	set average NaN
    } else {
	set average  [ expr $duration / $Replay_total_submissions.0 ]
	puts [ format {Average submission duration : %2.2f sec<br>} $average ]
    }
    puts [ format {Changed submissions: %s<br>} $Replay_changed_submissions ]
    
    puts {<h4>Complete</h4>}
}

## Delegate the reexecute of a submission to an external process
proc Submissions::delegate_execute {n sd} {
    variable Fd
    global REL_BASE DIR_BASE

    set Fd($sd) [ open "| tclsh" r+ ]
    puts $Fd($sd) [ format {lappend auto_path packages} ]
    puts $Fd($sd) [ format {set REL_BASE %s} $REL_BASE ]
    puts $Fd($sd) [ format {set DIR_BASE %s} $DIR_BASE ]
    puts $Fd($sd) [ format {package require execute}  ]
    puts $Fd($sd) [ format {package require file}  ]
    puts $Fd($sd) [ format {set ::Session::Conf(contest) %s} Replay ]
    puts $Fd($sd) [ format {set ::Session::Conf(style) %s} base ]
    puts $Fd($sd) [ format {set ::Session::Conf(controller) %s} none ]
    puts $Fd($sd) [ format {file::startup_tmp} ]
    puts $Fd($sd) [ format {Submissions::execute %s %s} $n $sd ]
    puts $Fd($sd) [ format {file::cleanup_tmp} ]
    puts $Fd($sd) [ format {exit} ]
    flush $Fd($sd)
    fileevent $Fd($sd) readable [ list Submissions::show_line $sd ]
}

## Wait for the termination of all processes 
proc Submissions::wait4processes {} {
    variable Fd

    while { ! [ catch { vwait Fd([ lindex [ array names Fd ] 0 ]) } ] } {}
}

## Reevaluate a submission, outputing a line to stdout 
## comparing the new classification with the recorded classification;
## if different the line is hilite in red.
proc Submissions::execute {n sd {update 0} {change 0}} {
    variable ::Session::Conf
    variable Replay_total_submissions
    variable Replay_changed_submissions
    variable Line_counter

    if [ catch {
	set sub [ data::open $sd ] 
	set before [ set ${sub}::Classify ]
    } ] {
	puts [ format {<font color="orange">%s</font>} \
		   "error loading submission: [ file tail $sd ]" ]
	return
    }

    # sanity check
    foreach var {Date Time Team Problem Language State Classify Mark} {
	if { ! [info exists ${sub}::${var}] || [set ${sub}::${var}] == "" } {
	    puts [ format {<font color="orange">%s</font>} \
		       "submission with empty fields: [ file tail $sd ]" ]
	    return
	}
    }

    if [ catch { $sd analyze } msg ] { puts -nonewline $msg }

    set after [ set ${sub}::Classify ]

    if $change {
	# record changing classifications
	data::record $sd
    }

    set sn [ file tail $sd ]
    if $update { incr Replay_total_submissions }
    if { ! [ string equal $before $after ] } {
	if $update { incr Replay_changed_submissions }
	puts -nonewline [ format {<font color="red">} ]
    }


    set format {<span style="background: %s;"> }
    append format {%4d <a target="select" href="%s?data+%s">%-35s</a> }
    append format {%-5s %-25s %-25s }
    append format {</span>}

    set language [ set ${sub}::Language ]
    if { ! [ info exists Line_counter ] } { 
	set Line_counter $n
    }
    layout::toggle_color Line_counter color
    puts  -nonewline [format $format $color $n $Conf(controller) \
			  $sd $sn $language $before $after ]
    if { ! [ string equal $before $after ] } {
	puts [ format {</font>} ]
    } else {
	puts ""
    }

}

## Read a single input line, copies to stdout and closes stream
proc Submissions::show_line {sd} {
    variable Replay_total_submissions
    variable Replay_changed_submissions
    variable Fd    

    gets $Fd($sd) line
    puts $line
    catch { close $Fd($sd) }

    unset Fd($sd)

    incr Replay_total_submissions
    if [ regexp {<font color="red">} $line ] {
	incr Replay_changed_submissions
    }
}

## Loads (some) submision variables to the calling procedure.
## It returns a boolean reporting if submission is ok (true)
proc Submissions::load_submission {sub} {

    if { [ catch  {
	set seg [ data::open $sub ]
    } ] } {
	return 0
    }


    foreach var {Date Time Team Problem Language State Classify Mark Size} {
	if {  [ info exists ${seg}::$var ] && [ set ${seg}::$var ] != "" } {
	    uplevel upvar ${seg}::$var $var
	} else {
	    puts stderr "missing $var"
	    return 0
	}
    }
    return 1
}

# Make time interval selector for listing header based on configuration
proc Submissions::mk_interval_selector {} {
    variable ::Session::Conf

    set time_intervals {}
    set time_interval_names {}
    foreach {d h m} {0 0 1 0 0 5 0 0 15 0 0 30 0 1 0 0 6 0 1 0 0} {
	lappend time_intervals [ expr (($d * 24 +$h) * 60 + $m) * 60 ]
	set name ""
	if { $d != 0 } { append name [ format { %s d} $d ] }
	if { $h != 0 } { append name [ format { %s h} $h ] }
	if { $m != 0 } { append name [ format { %s m} $m ] }

	lappend time_interval_names $name
    }
    
    return [ layout::menu time_interval $time_intervals \
		 $Conf(time_interval) $time_interval_names \
		 1 "this.form.submit();" Header ]
}
