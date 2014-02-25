#
# Mooshak: managing  programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: common.tcl
# 
## Requests common to several profiles (admin judge runner team guest) 
## These procs receive data from the command line and CGI variables
## and generate HTML layout in the stdout
##
## TODO: avoid using command sms by runner

package provide common 1.0


namespace eval common {

    variable MaxLabelSize 20	     ;## Truncate larger team names
    variable Available		     ;## Listings available for each profile
    array set Available {
	admin { 
	    pending questions submissions 
	    printouts balloons 
	    evolution statistics ranking 
	}
	judge { 
	    pending questions submissions 
	    printouts balloons 
	    evolution statistics ranking 
	}
	runner { 
	    pending printouts balloons evolution  statistics ranking 
	}
	guest  { 
	    submissions evolution  statistics ranking 
	}
	team {submissions printouts questions evolution  statistics ranking} 
    }
}

proc common::top {} {

    template::load
    template::write
}

## Toplevel judge window
proc common::judge {} {

    template::load common/profile
    template::write
}

## Toplevel runner window
proc common::runner {} {

    template::load common/profile
    template::write
}

## Toplevel runner window
proc common::guest {} {

    template::load common/profile
    template::write
}

# Manage check lists
proc common::check {{check_list ""} {file ""}} {

    if { $check_list == "" } {
	execute::header
	set path data/configs/checks
	data::open $path
	$path show
    } else {
	set path data/configs/checks/$check_list
	if { $file == "" } {
	    # show/record check list
	    execute::header
	    data::open $path
	    if { [ cgi::field data "" ] == "" } {
		$path show
	    } else {
		$path record
	    }
	} else {
	    # resource or report file
	    set fxs [ glob -nocomplain $path/{resources,reports}/$file ]
	    if { [ set fx [ lindex $fxs 0 ] ] != "" } { 
		if [ catch { admin::file $fx } msg ] {
		    execute::header
		    execute::report_error "Error" $msg
		}
		
	    } else {
		execute::header
		execute::report_error "Unreadable file" $file
	    }
	}
    }
}

## Generate the top left Mooshak banner with contest name and remaining time
proc common::banner {} {
    global VERSION

    translate::labels _users _teams _guests

    if [ contest::active 0 ] {
	if [ catch {
	    set contest [ contest::active_path ]
	    set sg [ data::open $contest ]
	} ] {
	    set remaining ""
	    set name [ format {<font color="orange"><i>%s</i></font> } \
			   [ translate::sentence "Invalid contest selected" ] ]
	} else {
	    set name [ set ${sg}::Designation ]
	    set remaining [ $contest remaining ]
	}
    } else {
	set name [ format {<font color="gray"><i>%s</i></font> } \
		       [ translate::sentence "No contest selected" ] ]
	set remaining ""
    }

    set nusers 0
    data::open data/configs/sessions
    set nusers  [ data/configs/sessions count ]
    set nadmins [ data/configs/sessions count "_admin" ]
    set nteams  [ data/configs/sessions count "_team" ]
    set nguests [ data/configs/sessions count "_guest" ]
    set njudges [ data/configs/sessions count "_judge" ]

    set session_count_info "Admin:<b>$nadmins</b>  Judge:<b>$njudges</b><br>"
    append session_count_info "Team:<b>$nteams</b>  Guest:<b>$nguests</b>"


    set now  [ clock format [ clock seconds ] -format {%H:%M} ]
    
    template::load
    template::write 
}

## Send a (short :-) message to an object
## A SAFER version of the message command
proc common::sms args {
    
    set dir [ lindex $args 0 ]
    set obj [ lindex $args 1 ]
    set args [ lrange $args 2 end ]

    set path [ contest::active_path ]/$dir/$obj
	      
    data::open $path
    eval $path $args

}


## Generates a problem description 
proc common::description {problem} {

    if [ catch { content::show_problem [ contest::active_path ] $problem } ] {
	layout::alert "Problem description unavailable"	
	empty
    }
}


## Generates image for problem descriptions
proc common::image {problem {image {}}} {
    variable ::Session::Conf
    global env 

    if { 
	[ string equal $Conf(profile) admin ] && 
	[ info exists env(HTTP_REFERER) ] &&
	[ regexp {content\?(.*)/problems} $env(HTTP_REFERER) - contest ] 
    } {
	# if admin then use contest from previous request to content
    } else {
	# other profiles (i.e. teams) can only see images from active contest
	set contest [ contest::active_path ]
    } 

    if { $image == {} } {
	set image $problem
	set file $contest/quiz/images/$image	
    } else {
	set file $contest/problems/$problem/images/$image
    }

    if { [ file readable $file ] } {
	set fd [ open $file r ]
	
	puts [ format "Content-type: %s\n" [ email::mime $image ] ]
	fconfigure $fd -translation binary
	fconfigure stdout -translation binary
	fcopy $fd stdout
	close $fd
    } else {
	puts [ format "Content-type: %s\n" text/HTML ]
	puts "<h2>Cannot open image $image in problem $problem</h2>"
    }
}

## Generate windows with tools aligned vertically
proc common::vtools {{grouped 0}} {
    variable ::Session::Conf
    variable Available

    translate::labels view problems_ teams_ update logout warning judge admin \
	_every _minutes _with _lines


    template::load
    set help_button [ layout::help_button interfaces ]

    template::write head
    switch $Conf(profile) {
	judge - guest {
	    data::open data/contests   

	    set contests [ data/contests selector Conf(contest) 1 1 0 ]
	    append contests \
		[ format {<input type="hidden" name="command" value="%s">} \
		      $Conf(profile) ]
	    
	    template::write $Conf(profile)

	}
	default {
	    template::write $Conf(profile)
	}
    }

    template::write view

    if [ contest::active 0 ] {

	set contest [ contest::active_path  ]

	if { $Conf(type) == {} } {
	    set checked checked
	} else {
	    set checked ""
	}
	foreach tool $Available($Conf(profile)) {
	    if { [ string equal $Conf(type) $tool ] } {
		set checked checked
	    }
	    set label [ translate::sentence [ string totitle $tool ] ]
	    template::write listing
	    set checked ""
	}	

	set problems [ sorted_dir_options $contest problems Name ]
	if $grouped {
	    set grouped_checked "checked"
	    set grouped_toggle 0
	    set teams [ grouped_team_options $contest ]
	} else {
	    set grouped_checked ""
	    set grouped_toggle 1
	    set teams [ sorted_dir_options $contest groups/* Name ]
	}

    } else {

	set grouped_checked ""
	set grouped_toggle 1

	template::write inactive_$Conf(profile)

	set problems 	{}
	set teams	{}
    }

    set time	[ layout::menu time { 1 2 5 } [ cgi::cookie time 5 ] ]
    set lines	[ layout::menu lines { 15 20 50 100 200 } \
		      [ cgi::cookie lines 15 ] ]

    template::write rest

    template::write foot
}


## returns options for team selector sorted alphabetically
proc common::sorted_dir_options {contest dir var} {
    variable MaxLabelSize
    variable Name

    set options ""

    set dirs {}
    foreach td [ glob -nocomplain -type d $contest/$dir/* ] {
	set t [ data::open $td ] 
	set Name($td) 	[ set ${t}::${var} ]
	lappend dirs	$td
    }
    
    foreach td [ lsort -command {common::cmp Name} $dirs ] {
	set id	[ file tail $td ]
	set label 	[ layout::fit_label $Name($td) $MaxLabelSize ]
	append options [format {<option value="%s">%s</option>} $id $label ]
    }

    return $options
}

## returns options for team selector grouped (by groups, of course :-)
proc common::grouped_team_options {contest} {
    variable MaxLabelSize
    variable Acronym
    variable Name

    set teams ""

    set group_dirs {}
    foreach gd [ glob -nocomplain -type d $contest/groups/* ] {
	set g [ data::open $gd ]
	set Acronym($gd)	[ set ${g}::Acronym ]
	lappend group_dirs $gd
    }

    foreach gd [ lsort -command {common::cmp Acronym} $group_dirs ] {
	
	set team_dirs {}
	foreach td [ glob -nocomplain -type d $gd/* ] {
	    set t [ data::open $td ] 
	    set Name($td) 	[ set ${t}::Name ]
	    lappend team_dirs	$td
	}

	foreach td [ lsort -command {common::cmp Name} $team_dirs ] {
	    set id	[ file tail $td ]
	    set label 	[ layout::fit_label $Acronym($gd):$Name($td) \
			      $MaxLabelSize]
	    append teams [format {<option value="%s">%s</option>} $id $label ]
	}
    }

    return $teams
}


## compare indexes if a given field (as a namespace variable)
proc common::cmp {field a b} {
    variable $field

    return [ string compare [ set ${field}($a) ] [ set ${field}($b) ] ]
}


## Form for judges to send warnings to teams 
proc common::warn {} {
    variable ::Session::Conf

    if { ! [regexp {admin|judge} $Conf(profile)] || ! [contest::active 0] } {
	empty
	return 
    }

    set contest	 [ contest::active_path ] 
    
    data::open $contest/problems 

    set problems ""
    set s ""
    foreach p [ lsort [ $contest/problems problems ] ] {

	set prob [ data::open $contest/problems/$p ]

	foreach {var att def} {name Name ? color Color white} {
	    if [ info exists ${prob}::${att} ] {
		set $var [ set ${prob}::${att} ]
	    } else {
		set $var $def
	    }
	}   

	append problems [ format {<input %s } $s]
	append problems {type="radio" name="problem" }
	append problems [ format {value="%s" } $p ]
	append problems [ format {style="background: %s;"> %s } $color $name ]
	append problems "&nbsp;&nbsp;"

	append problems {&nbsp;&nbsp;}
    }

    set Team ""

    
    template::load
    template::write
}

## processes a judge warning
proc common::warned {} {
    variable ::Session::Conf

    set team ""
    set problem	[ cgi::field problem "" ]

    set question  [ contest::transaction questions $problem $team ]
    data::new $question Question 
    
    data::open $question
    $question warned
    data::record $question 

    layout::redirect $Conf(controller)?command=listing&type=questions

}

## Splits a window using frames
proc common::split args {
    global auto_path
    variable ::Session::Conf

    if { [ set command [ cgi::field command {} ] ] != "" } {

	set selector  $command
	set variables [ cgi::url_encode_state ]
    } else {
	set command [ lindex $args 0 ]
	set arguments [ join $args + ]

	#special cases: message and sms
	switch $command {
	    sms {
		set command  $Conf(controller)?
		set selector [ lindex $args 3 ]
		
	    }
	    message {
		set command  $Conf(controller)?
		set selector [ lindex $args 2 ]
	    }
	    default { set selector $command }
	}
    }

    template::load 

    template::write $selector
}

## Show report for given submission
proc common::report {submission report} {
    
    set contest	[ contest::active_path ]
    set path $contest/submissions/$submission

    if { $report == "" } {
	set sub [ data::open $path ]
	set report [ set ${sub}::Report ]
    }

    set fxr $path/$report
    
    set mime [ email::mime $report ]

    puts "Content-type: $mime"
    puts ""
    
    if { [ string equal $mime "text/xml" ] } {
	puts {<?xml-stylesheet type="text/xsl" href="../../styles/report.xsl"?>}
    }

    if { [ file readable $fxr ] } {
	set fd [ open $fxr r ]
	
	fconfigure $fd -translation binary
	fconfigure stdout -translation binary
	fcopy $fd stdout
	close $fd
    } else {
	execute::report_error "file not found" $fxr
    }
}


## Generates an empty page
proc common::empty {} {
    template::load empty.html
    template::write 

}
