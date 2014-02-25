#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: team.tcl
# 
## Processes commands originating in the teams interface
##
## TODO: review FAQ text

package provide team 1.0

namespace eval team {

    variable Fork_evaluation	0     ;# run evaluation as separate process
    variable Params			;#  units of params

    namespace export analyse	;## Receives program submition for evaluation
    namespace export ask	;## Generates a form for questioning judges
    namespace export asked	;## Receives question for judges
    namespace export answer	;## Show an answer
    namespace export htools	;## Generated teams' tool window
    namespace export print	;## Receives a file for printing
    namespace export view	;## Visualization of problem description    
    namespace export faq	;## Generates FAQ for teams. 

    set Params {
	MaxCore			Kb
	MaxData			Mb
	MaxOutput		Kb
	MaxStack		Mb
	MaxProg			Kb
	RealTimeout		sec
	CompTimeout		sec
	ExecTimeout		sec
    }

}

## Toplevel team window
proc team::team {} {
    variable ::Session::Conf

    set contest [ contest::active_path ]
    set team $Conf(user)
    set seg [ data::open $contest ]

    data::open $contest/submissions

    if { 
	[ info exists ${seg}::challenge ] && 
	[ string equal [ set ${seg}::challenge ] quiz ] 
    } {
	if { [ set message [ $contest/submissions acceptable $team ] ] == "" } {
	    data::open $contest/quiz

	    execute::generator {$contest/quiz sheet 0}
	} else {

	    execute::header

	    set Conf(message) [ lindex $message 0 ]
	    Session::authenticate login {}
	} 	    	


    } else {
	execute::header
       
	template::load
	template::write
    }

    set team [ glob $contest/groups/*/$Conf(user) ]
    data::open $team

    $team record_login_time

}

## Grade a quiz
proc team::grade {} {
    variable ::Session::Conf
    set contest [ contest::active_path ]
    data::open $contest/quiz
    data::open $contest/submissions

    set team $Conf(user)

    if { [ set message [ $contest/submissions acceptable $team ] ] == "" } {
	execute::generator {$contest/quiz sheet 1}
    } else {
	global errorInfo

	set errorInfo $message
	execute::header
	execute::report_error [ lindex $message 0 ]
    }
}

## Generates team's tools window (with horizontal alignment)
proc team::htools {} {
    global VERSION 

    set contest [ contest::active_path ]

    set seg [ data::open $contest ]
    data::open $contest/problems 
    data::open $contest/languages
    data::open $contest/groups
    
    set prt [ data::open $contest/printouts ]
    if [ $contest/printouts active ] {
	set printing ""
    } else {
	set printing " disabled "
    }

    set qst [ data::open $contest/questions ]
    if [ $contest/questions active ] {
	set asking ""
    } else {
	set asking " disabled "
    }

    translate::labels submit view ask print help logout

    foreach {team_name} \
	[ $contest/groups identify [ contest::team ] {} {Name} ] {}

    set designation [ set ${seg}::Designation ]
    set time	[ layout::menu time { 1 2 5 } [ cgi::cookie time 5 ] ]
    set lines	[ layout::menu lines { 5 10 15 20 50 100 200 } \
	[ cgi::cookie lines 15 ] ]
    set languages [ $contest/languages JS_array ]
    set problems  [ $contest/problems selector ]

    set print_disabled false

   template::load
   template::write
}


## Receives program submition for evaluation 
proc team::analyze {} {
    variable ::Session::Conf

    set contest [ contest::active_path ]
    data::open $contest
    set now [ clock seconds ]

    set problem [ cgi::field problem ]
    set problem_dir $contest/problems/$problem
    data::open $problem_dir

    # double check status and elapsed time because of virtual contests
    # and check if thisproblem is available
    if { 
	[ $contest status {running "running virtually" } ] 	&&
	[ $contest passed ] < [ $contest duration ] 		&&
	[ expr [ $problem_dir start ] <= $now  ] 		&&
	[ expr [ $problem_dir stop  ] >= $now  ]
    } {	
	set message [ do_analyze $contest ]
    } else {

	if { [ expr [ $problem_dir start ] > $now  ] } {
	    set message "Problem $problem:"
	    lappend message [ is_early [ expr [ $problem_dir start ] - $now ] ]

	} elseif { [ expr [ $problem_dir stop  ] < $now  ] } {
	    set message "Problem $problem:"
	    lappend message [ is_late [ expr $now - [ $problem_dir stop ] ] ]

	} else {
	    set message [ $contest not_allowed Submissions ]
	}
    }
    
    if { $message != "" } {
	execute::record_error $message

	# translate message list before coloring
	set message_list $message
	set message {}
	foreach sentence $message_list {
	    lappend  message [ translate::sentence $sentence ]
	}

	color_message_list message
    } else {
	set message [ list "Submission received" ]
    }
    
    set fields [ list command=listing type=submissions ]
    if [ info exists problem ] { lappend fields  [ list problem=$problem ] }
    set fields [ join $fields & ]
    
    # mark this session as modified now for cache control
    set Conf(modified) [ clock seconds ]

    request $Conf(controller)?$fields $message
}

## Processes a valid program submission.
## A transaction is created to record the submission
proc team::do_analyze {contest} {
    variable Fork_evaluation
    
    data::open $contest/submissions
    
    set team	[ contest::team ]
    set problem	[ cgi::field problem ]

    set message [ $contest/submissions acceptable $team $problem ]
    if { $message == "" } {
	
	set duration [ $contest passed ]
	set dir [ contest::transaction submissions $problem $team ]
	
	set sub  [ data::new $dir Submission ]
	
	if { [ $dir receive ] } {
	    
	    set message {}
	    data::record $dir
	    
	    if $Fork_evaluation {
		# NOT WORKING
		set fd [ open "| nohup admin/analyze $dir" r ]
		while { [ set r [ gets $fd line ] ] > -1 } {}
		if [ catch { close $fd } msg ] {
		    execute::record_error $msg
		}		
	    } else {
		$dir analyze
		data::record $dir
	    }
	} else {
	    set message [ list  "Submission NOT received" : \
			      "upload error (please retry)" ]
	}
    }
    return $message
}


## Generates a form for asking a question to the judges
proc team::ask {{problem ""}} {
    variable ::Session::Conf

    set contest [ contest::active_path ]
    data::open $contest

    if {  [ $contest status {running "running virtually" finished} ] } {
	if { $problem == "" } {
	    # header 
	    set problem [ cgi::field problem ]
	    set prob [ data::open $contest/problems/$problem ]
	    foreach {var att def} {name Name ? title Title ""} {
		if [ info exists ${prob}::${att} ] {
		    set $var [ set ${prob}::${att} ]
		} else {
		    set $var $def
		}
	    }   

	    set page $Conf(controller)?ask+$problem
	    set message [ list "Question about problem" $name : $title ] 
	    request $page $message
	} else {	
	    # form
	    set team [ contest::team ]

	    template::load
	    template::write
	}
    } else {
	set page  $Conf(controller)?command=listing&type=questions&problem=$problem 
	set message [ $contest not_allowed Questions ]
	request $page $message
    }
}


## Receives a question to the human judges. 
## A transaction is created to record the question.
proc team::asked {} {
    variable ::Session::Conf

    set contest [ contest::active_path ]
    data::open $contest
    

    if {  [ $contest status {running "running virtually" finished} ] } {
	set team	[ contest::team ]
	set problem	[ cgi::field problem ]

	set dir [ contest::transaction questions $problem $team ]
	data::new $dir Question

	$dir receive

	data::record $dir

	set message [ list "Question received" ]
    } else {
	set message  [ $contest not_allowed Questions ]
    }

    # mark this session as modified now for cache control
    set Conf(modified) [ clock seconds ]

    set fields [join [list command=listing type=questions problem=$problem] & ]
    request  $Conf(controller)?$fields  $message
}

## Show an answer
proc team::answer {question} {

    set contest [ contest::active_path ]    
    set path $contest/questions/$question
    
    if { ! [ file exists $path ] } { 
	execute::report_error "Wrong question" 
    } else {
	data::open $path
	$path answer
    }
}

## Visualization of problem description
proc team::view {{problem ""}} {

    set contest [ contest::active_path ]
    data::open $contest

    if { $problem == "" } {
	# First call: show title    
	view_title $contest 
    } else {
	# Second call: show problem description

	set problem_dir $contest/problems/$problem
	data::open $problem_dir
	set now [ clock seconds ]

	if { 
	    [ $contest status {running finished "running virtually"} ] &&
	    [ expr [ $problem_dir start ] <= $now  ] &&
	    [ expr [ $problem_dir stop  ] >= $now  ]
	} {
	    # double check if contest has REALLY started
	    # and if problem description available
	    content::show_problem $contest $problem
	} else {
	    template::load empty.html
	    template::write 
	}

    }

}

## Generate a title to problem description
proc team::view_title {contest} {
    variable ::Session::Conf

    set problem [ cgi::field problem ]

    set problem_dir $contest/problems/$problem

    if { ! [ file readable $problem_dir ] } {
	set page $Conf(controller)?listing 
	set message [ list "Unknown problem" : $problem ]
    } else {
		
	set prob [ data::open $problem_dir ]
	foreach {var att def} {name Name ? title Title ""} {
	    if [ info exists ${prob}::${att} ] {
		set $var [ set ${prob}::${att} ]
	    } else {
		set $var $def
	    }
	}   

	set comment ""

	set now [ clock seconds ]	
	set pre [ expr [ $problem_dir start ] - $now ]
	set pos [ expr $now - [ $problem_dir stop ] ]
	set more [ expr [ $contest stop ] - [ $problem_dir stop ] ]

	if { $pre > 0 } {
	    set title [ format {<i>%s</i>} [ is_early $pre ] ]
	} elseif { $pos > 0 } {
	    set title [ format {<i>%s</i>} [ is_late $pos ] ]
	} elseif { $more > 0 } {
	    set time [ expr [ $problem_dir stop ] - $now ]
	    set comment [ format {: <i>%s</i>} [ is_available $time ] ]
	}



	if { ! [ $contest status {running finished "running virtually"}  ] } {
	    set title  [ format {<i>%s</i>} \
				   "Problem description unavailable" ] 
	}
	# this will be the second call to view
	set page $Conf(controller)?view+$problem 
	set message [ list  "Problem description" $name : $title $comment ]
	
    }

    request $page $message 
}


## Receives a file sended by the team for printing.
## A transaction is created to record the printout.
proc team::print {} {
    variable ::Session::Conf

    set contest [ contest::active_path ]
    data::open $contest
    
    if { [ $contest status {running finished} ] } {
	set team	[ contest::team ]
	set problem	[ cgi::field problem ]
	set program	[ cgi::field program ]
	
	if { $problem == "" } {
	    set message [ list "Printout NOT accepted" : "Missing problem" ]
	} elseif { $program == "" } {
	    set message [list "Printout NOT accepted" : "Missing program file"]
	} else {

	    set dir [ contest::transaction printouts $problem $team ]
	    data::new $dir Printout
	    
	    set message [ $dir receive ]
	    
	    data::record $dir
	}	
    } else {
	set message [ $contest not_allowed Printouts ]
    }



    if { $message != "" } {
	execute::record_error $message
    } else {
	set message [ list "Printout accepted" ]
    }
    
    set fields [ join [ list command=listing type=printouts ] & ]
    request $Conf(controller)?$fields $message
}

## Generates sumission code if requested by owner
proc team::code {sub} {

    set contest [ contest::active_path ]
    set dir $contest/submissions/$sub

    if { ! [ file exists $dir ] } { 
	execute::report_error "Wrong submission" 
    }

    set sd [ data::open $dir ]

    if { ! [ string equal [ contest::team ] [ set ${sd}::Team ] ] } {
	execute::report_error "Invalid user"
    }

    if [ catch { set fd [ open $dir/[ set ${sd}::Program ] r ]  } ] {
	execute::report_error "Cannot read file"
    }

    fconfigure $fd -translation binary
    fconfigure stdout -translation binary
    fcopy $fd stdout
    close $fd
}

## Generates team status window with a message and a redirection to page
proc team::request {page message_list} {

    set message {}
    foreach sentence $message_list {
	lappend  message [ translate::sentence $sentence ]
    }

    set message	  [ join $message " " ]
    set command	  [ update_form $page ]
    set contest   [ contest::active_path ]

    data::open $contest
    set remaining [ $contest  remaining ]
    
    listing::reset

    template::load team/request

    template::write {}
}


## Generates FAQ for teams. Language parameters are read from contest
proc team::faq {} {
    variable Params

    set contest [ contest::active_path ]

    template::load 
    
    data::open $contest/languages
    array set Param [ $contest/languages params ]
    
    set languages ""
    foreach lp [ lsort [ $contest/languages all ] ] {
	set ling [ data::open $lp ]
	foreach var {Name Extension Compiler Version Compile} {
	    set [ string tolower $var ] [ set ${ling}::${var} ]
	}
	set compile [ file tail $compile ]
	append languages [ template::formatting ling ]
    }

    set params ""
    foreach {p u} $Params {
	set text [ template::formatting $p ]
	switch $u {
	    Kb		{ set value [ expr $Param($p) / 1024 ]		}
	    Mb		{ set value [ expr $Param($p) / 1024 / 1024 ]	}
	    default	{ set value $Param($p) 				}
	}
	set value "$value $u"
	append params [ template::formatting param ]
    }

    template::write 
}

## Return a JS instruction to update team's form
proc team::update_form {page} {

    if [ regexp {^listing} $page ] {	
	if [ regexp {type=([a-z]+)} $page - listing ] {	
	    array set number {
		submissions 0
		ranking 1
		questions 2
		printouts 3
	    }
	    set pos $number($listing) 
	} else {
	    set pos 0
	}
	set inst {top.frames[0].document.forms[2].command[%d].checked=true;}
	return [ format $inst $pos ]
    } else {
	return ""
    }
}

## Produce a feedback page for this submission
proc team::feedback {submission number} {
    variable ::Session::Conf

    template::load

    set contest [ contest::active_path ]
    if { $submission == "" } {
	execute::record_error "submission required"
	return
    }

    set path $contest/submissions/$submission

    set sub [ data::open $path ]

    foreach var { Team Feedback Observations } {
	if { [  info exists ${sub}::${var} ] } {
	    set [ string tolower $var ] [ set ${sub}::${var} ]
	} else {
	    set [ string tolower $var ] ""
	}
    }
	
    if { ! [ string equal $team $Conf(user) ] }	{       
	set feedback [ format "Invalid user/team %s" $Conf(user) ]
	execute::record_error $feedback
    }

    set feedback [ join [ etc::invert $feedback ] "<hr>" ]

    template::write   
}

## Colors in red (html) each item of a list of message
proc team::color_message_list {message_} {
    upvar $message_ message

    set plain_message $message

    set message {}
    foreach item $plain_message {
	layout::color item red
	lappend message  $item
    }
}

## Message showing how early it is
proc team::is_early {pre} {
    set time [ clock format $pre -format "%H:%M:%S" -gmt 1 ]
    return [ format \
		 [ translate::sentence "Not yet available - wait %s" ] \
		 $time ] 
}

## Message showing how late it is
proc team::is_late {pos} {
    set time [ clock format $pos -format "%H:%M:%S" -gmt 1 ]
    return [ format \
		 [ translate::sentence "Not available anymore - %s late"] \
		 $time ] 
}

## Message showing how musch time is available
proc team::is_available {pos} {
    set time [ clock format $pos -format "%H:%M:%S" -gmt 1 ]
    return [ format \
		 [ translate::sentence "Available for %s"] \
		 $time ] 
}
