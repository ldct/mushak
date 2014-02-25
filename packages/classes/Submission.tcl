#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Submission.tcl
# 
## Submition of a source program to solve a problem (run)
##
## TODO: a single way of displaying differences between expected and obtain output

package provide Submission 1.0

namespace eval Submission {

    variable Results			;# list of possible results
    variable States			;# list of possible states
    variable ReportFileName Report.html	;# report filename
    variable SmallOutput 500		;# small enough for character diff
    variable Contest			;# pathname of this contest
    variable Param			;# parameters for compilation/execute
    variable Sub			;# computed parameter for current run
    variable Timeout	1		;# default timeout
    variable Skip_tests 0		;# should skip remaining tests?
    variable MaxLabelSize 30	        ;## Truncate larger team names
    variable Service 0			;# is running as service

    array set Sub {
	contest_name	?
	language	?
    }

    set Results {
	"Accepted"		      
	"Presentation Error"		
	"Wrong Answer"			
	"Output Limit Exceeded"
	"Memory Limit Exceeded"
	"Time Limit Exceeded"
	"Invalid Function"
	"Runtime Error"
	"Compile Time Error"
	"Invalid Submission"
	"Program Size Exceeded"
	"Requires Reevaluation"
	"Evaluating"
    }

    set States { "pending" "final" }

}

#-----------------------------------------------------------------------------
#     Class definition

Attributes Submission \
    [ list								\
	  Date		date		{}				\
	  Time		text		{}				\
	  Problem	ref		{../../problems}		\
	  Team		ref		{../../groups/*}		\
	  Classify 	menu		$Submission::Results		\
	  Mark		text		{}				\
	  Size		text		{}				\
	  Observations	text		{}				\
	  Execution	text		{}				\
	  State		menu		 $Submission::States		\
	  Language	ref		{../../languages}		\
	  Program	fx		{}				\
	  Report 	fx		{.html} 			\
	  Elapsed	text		{}				\
	  CPU		text		{}				\
	  Memory	text		{}				\
	  Feedback	long-text	{}
	 ]

## New submission
Operation Submission::new {} {
    variable States

    return [ string equal $State [ lindex $States 0 ] ]
}

## Process a team submission 
Operation Submission::receive_quiz {mark} {
    variable States
    variable Results
    variable ReportFileName
    variable UsageFileName

    set pid [ pid ]

    set sbs [ data::open  ${_Self_}/.. ]
    if { ! [ info exists ${sbs}::Default_state ] ||
	 [ set default_state [ set ${sbs}::Default_state ] ] == {}
     } {
	set default_state [ lindex $States 0 ]
    }

    set Date 		[ clock seconds ]
    set Time		[ contest::transaction_time ]
    
    set Team		[ contest::team ]
    set Problem		"-"
    set Classify	[ lindex $Results 0 ]
    set Mark		$mark
    set Size		0
    set Observations 	$pid
    set Execution	"-1"
    set State		$default_state
    set Program		"quiz.xml"
    set Language	"Quiz"
    set Report		$ReportFileName
    set Elapsed		0
    set CPU		0
    set Memory		0
    set Signals		0

    return 1
}



## Process a team submission 
Operation Submission::receive {} {
    variable States
    variable Results
    variable ReportFileName
    variable UsageFileName
    variable ::file::TMP

    set pid [ pid ]

    set sbs [ data::open  ${_Self_}/.. ]
    if { ! [ info exists ${sbs}::Default_state ] ||
	 [ set default_state [ set ${sbs}::Default_state ] ] == {}
     } {
	set default_state [ lindex $States 0 ]
    }

    set Date 		[ clock seconds ]
    set Time		[ contest::transaction_time ]
    set Problem		[ cgi::field problem ]
    set Team		[ contest::team ]
    set Classify	[ lindex $Results end ]
    set Mark		0
    set Size		0
    set Observations 	$pid
    set Execution	"-1"
    set State		$default_state
    set Program		[ cgi::field program ]
    set Language	""
    set Report		$ReportFileName
    set Elapsed		0
    set CPU		0
    set Memory		0
    set Signals		0
    if { $Program == "" } { return 0 }
	
    if { ! [ file exists $TMP/$Program ] } { return 0 }
    
    # avoid funny chars in filenames, replace them by underscores
    set filename $Program
    regsub -all {[^_\w\.]} $Program {_} Program

    file rename -force $TMP/$filename ${_Self_}/$Program
    file attributes ${_Self_}/$Program -permissions u=r
    set Size  [ file size ${_Self_}/$Program ]

    return 1
}

## Set pathname to related directories
Operation Submission::set_contest {} {
    variable Contest

    set Contest	  [ file::canonical_pathname ${_Self_}/../.. ]
}


## Modification of submission by an human judge 
Operation Submission::modify {{n ?}} {
    variable ::Session::Conf
    variable States
    variable Results
    variable Contest

    set save_changes 0	;# flag: save changes in this submission?

    # mark this session as modified now for cache control
    set Conf(modified) [ clock seconds ]
    set previous_state $State

    ${_Self_} set_contest

    data::open $Contest
    data::open $Contest/groups
    
    set policy [ $Contest policy ]
    if { [ ${policy}::subjective ] } {
	set type text
    } else {
	set type hidden
    }


    set todo ""
    foreach var { Classify State Mark Report todo } {
	if { 
	    [ info exists cgi::Field($var) ] 		&& 
	    ! [ string equal $cgi::Field($var) [ set $var ] ]
	} {
	    set $var $cgi::Field($var)
	    if { ! [ regexp {^(todo|Report)$} $var ] } {
		set save_changes 1
	    }
	}
    }

    foreach {group_color group_flag group_acronym team_name} \
	[ $Contest/groups identify $Team {Color Flag Acronym} {Name} ] {}

    # if todo is reevalute (or "reavaliar") hugly :-( 
    if [ regexp -nocase {^re} $todo ] {
	${_Self_} analyze
    }

    set reports {}
    set report_names {}
    foreach fx [ lsort -command file::newer \
		     [ glob -nocomplain ${_Self_}/*.html ] ] {
	lappend report_names	[ file rootname [ file tail $fx ] ]
	lappend reports		[ file tail $fx ] 
    }
    
    # if todo is reevalute (ou reavaliar) hugly :-( 
    if [ regexp -nocase {^re} $todo ] {
	set Report [ lindex $reports end ]
    }

    if { [ llength $reports ] > 1 } {
	set report [ layout::menu Report $reports $Report $report_names ]
    } else {
	set report [ format 						    \
			 {%s<input type="hidden" name="Report" value="%s">} \
			 $report_names $reports	 ]
    }
    set result [ layout::menu	Classify $Results $Classify	]
    set state  [ layout::choose	State    $States  $State 	]
    set time   [ date::from_long_sec $Time			]
    set sub    [ file tail ${_Self_} ]
    set message ""

    layout::color result \
	[ expr [ lsearch $Results $Classify ] == 0 ?"green":"red" ]
    
    if { [ lsearch $States	$State		] == 0 } {
	#set state <b>$state</b>
    } else {
	layout::color state gray
    }

    # if state changes then patch cache (to avoid invalidation)
    if { ! [ string equal $State $previous_state ]  } {       
	$Contest patch_cache $sub $State
    }

    if $save_changes  {
	set page	$Conf(controller)?command=listing
	set window	top
    } else {	
	if { [ file exists ${_Self_}/$Report ] } { 
	    set page	$Conf(controller)?report+$sub+$Report
	} else {
	    set page	$Conf(controller)?empty
	}
	set window	report
    }    

    template::load 
    template::write    

    if { [ string compare [ lindex $Results end ] $Classify ] == 0 } {
	# if analyser is still running (pending classification)
	
	set pid $Observations
	if { [ file exists /proc/$pid ] } {
	    set message "Analyzer running"
	} else {
	    set message "Analyzer stoped"
	}
	
	layout::alert $message
    }

    # if accepted and final (and not already filled) then fill ballon !!
    if { 
	[ string equal $Classify	[ lindex $Results   0   ] ]	&&
	[ string equal $State		[ lindex $States    end ] ]	&&
	[ data::open $Contest/balloons ] != {}	     			&&
	 ! [ $Contest/balloons filled $Team $Problem ]
    } {
	Balloon::fills $Contest $Problem $Team

	data::open data/configs/sessions
	data/configs/sessions notify "Congratulations, you problem was accepted" $Team
    }

    if $save_changes { data::record ${_Self_} }
}

#### DEPRECATED !!!?
## Show available feedback for this submission
# Operation Submission::show_feedback {} {

#     template::load 
#     template::write
# }


## Reanalizes a submission at humand judge request
Operation Submission::reanalyze ! {

    ${_Self_} analyze

    set report \
	[ lindex [ lsort -decreasing [glob -nocomplain ${_Self_}/*.html] ] 0 ]
    if { $report == "" } {
	content::show ${_Self_} 1
    } else {
	content::show $report 1
    }
}

## Analyze a submision, records Result and Observations and produces a report
Operation Submission::analyze { {service 0} {language ""} } {
    variable Contest
    variable Results
    variable Sub
    variable Service

    if $service { set Service 1 ; set Language $language }

    if $service {
	set template 	"Submission/analyze.xml"
	set time_format "%Y-%m-%dT%H:%M:%S"
	set ext xml
    } else {
	set template "Submission/analyze.html"
	set time_format "%a %b %d %H:%M:%S %z %Y"
	set ext html
    }

    ${_Self_} set_contest

    set Sub(contest_name) 	[ contest::active_path ]
    set id   		[ file tail $_Self_ ]
    set now		[ clock seconds ]
    set received	[ clock format $Date -format $time_format ]
    set processed	[ clock format $now  -format $time_format ]
    set delay		[ date::from_long_sec [ expr $now - $Date ] ]
    set nrels 		[ llength [glob -nocomplain ${_Self_}/\[0-9\]*.html] ]
    set Report 		[ incr nrels ].$ext

    template::load $template
    template::record head

    set Classify  [ lindex $Results 0 ]

    if { 
	[ ${_Self_} check_team 			] &&
	[ ${_Self_} check_language		] &&
	[ ${_Self_} check_problem	       	] &&
	[ ${_Self_} check_program		] &&
	[ ${_Self_} check_compilation		] 
    } {
	# all static checks successful -> proceed with dynamic tests
	set summary_info [ ${_Self_} run_tests ]
    } else {
	set summary_info [ list [lsearch $Results $Classify] $Observations "" ]
    }

    data::open $Contest/submissions
    set Observations	[ $Contest/submissions get_observations $summary_info ]

    if $Service {
	set formatted_feedback {}
	foreach {type item} [ feedback::summarize_service \
			   $Problem $Team $summary_info ] {
	    lappend formatted_feedback [ template::formatting feedback_item ]
	}
	set Feedback [ join $formatted_feedback "\n" ]

    } else {
	set Feedback  	[ $Contest/submissions get_feedback \
			      $Problem $Team $summary_info ]
    }

    set code [ ${_Self_} show_file ]

    template::record foot

    # save report in HTML format
    set template::Channel [ open ${_Self_}/$Report  w ]
    template::show   
    catch { close $template::Channel }
    set template::Channel stdout

    set team [ glob -nocomplain ${_Self_}/../../groups/*/$Team ]
    data::open $team
    $team cache_clean
}

## Show submitted file in report
Operation Submission::show_file {} {
    variable SmallOutput

    set file ${_Self_}/$Program

    switch -regexp [ file::type $file ] {	
	text {
	    if { [ string length $Program ] < $SmallOutput } {
		set code [ layout::protect_html [ file::read_in $file ] ]
	    } else {
		set code  [ format {<font color="orange"><i>%s</i></font>} \
				[ translate::sentence "Program too long: truncated" ]]
		append code [ string range $Program 0 $SmallOutput ]...
		
	    }	    
	}

	default {
	    set code [ format {<center><i>%s</i></center>} \
			   [ translate::sentence "not a text file" ] ]
	}
    }
    return $code
}


## 1 - Check team making this submission. Possible "Invalid Submission" .
Operation Submission::check_team {} {
    variable Results
    variable Contest
    variable Sub

    data::open $Contest/groups

    if { [ set group [ $Contest/groups group_of_team $Team ] ] == "" } {
	set Classify [ lindex $Results 9 ]	;# "Invalid Submission"	

	set Observations [ translate::sentence "unknown team" ]:$Team
	set status 0
    } else {
	foreach {group_acronym team_name} \
	    [ $Contest/groups identify $Team {Acronym} {Name} ] {}
	template::record team

	set status 1
    }
    return $status
}


## upvar needs to refer to 3 levels in Operations !!


## 2 - Check if language is admissible and sets language and its Params.
##     Possible "invalid submission"	
Operation Submission::check_language {} {
    variable Results
    variable Contest
    variable Service
    variable Param
    variable Sub
    
    data::open $Contest/languages
    array set Param [ $Contest/languages params ]
    
    if { $Service && [ info exists Language ] && $Language != "" } {
	set Sub(language) $Contest/languages/$Language
	set ling [ data::open $Sub(language) ]
	set status 1
    } elseif {[set Sub(language) [$Contest/languages search $Program]] == {} } {
	set Classify [ lindex $Results 9 ]	;# "Invalid Submission"
	set Language ?
	set Observations [ translate::sentence \
		"unknown language" ]:[ file extension $Program ]
	set status 0
    } else  {
	set ling [ data::open $Sub(language) ]
	set Language  [ set ${ling}::Name ]
	set status 1
    }

    template::record language
    return $status
}


## 3 - Check if problem exists and sets its name and title
##     Possible "Invalid Submission"	
Operation Submission::check_problem {} {
    variable Results
    variable Contest
    variable Timeout
    variable Param
    variable Sub

    set pd $Contest/problems/$Problem
    if { $Problem == "" || ! [ file readable $pd ] } {	
	set Classify [ lindex $Results 9 ]	;# "Invalid Submission"	
	set Observations [ translate::sentence "unknown problem" ]:$Problem
	foreach var { problem_name title } {
	    set $var ""
	}
	set status 0
    } else {
	set prob [ data::open $pd ]
	set problem_name  [ set ${prob}::Name ]
	set title  [ set ${prob}::Title ]
	if {
	    ! [ info exists ${prob}::Timeout ] 			||
	    [ set timeout [ set ${prob}::Timeout ] ] == "" 	||
	    ! [ regexp {^\d+$} $timeout ] 
	} {
	    set timeout $Timeout
	    execute::record_error "problem $Problem with invalid timeout: '$timeout'"
	}
	set Param(ExecTimeout) $timeout	;# change default execute timeout
	set status 1
    }
    template::record problem 
    return $status
}

## 4 - Check program size. Possible "Program Size Exceeded"
Operation Submission::check_program {} {
    variable Results
    variable Param
    variable Sub

    # Size is a new attribute. It may not exist in older submissions
    if { ! [ info exists Size ] || ! [ regexp {^[0-9]+$} $Size ] } {
	set Size  [ file size ${_Self_}/$Program ]
    }
    if { $Size > $Param(MaxProg) } {
	set Classify [ lindex $Results 10 ]	;# Program Size Exceeded
	set status 0
    } else {
	set status 1
    }
    return $status
}     

## 5 - Compile program and check compilation errors.
##     Possible "Compile Time Error"
Operation Submission::check_compilation {} {
    variable Results
    variable Contest
    variable Sub
    variable Param

    if { [ catch {
	$Sub(language) compile ${_Self_} $Program $Problem Param 
    } Observations ] } {
	set Classify	[ lindex $Results 8 ]	;# Compile Time Error
	set status 0
    } else {
	set Observations ""
	set status 1
    }
    template::record compile
    return $status
}

## 6 - Execute and record ALL tests, reporting the most severe error
##     Possible errors:
Operation Submission::run_tests {} {
    variable Results
    variable Contest
    variable Sub
    variable Skip_tests 
    global errorInfo

    set prob [ ::data::open $Contest/problems/$Problem ]
    set solution ""
    if [ info exists ${prob}::Static_corrector ] {
	set static_corrector [ set ${prob}::Static_corrector ]
	if { [ info exists ${prob}::Program ] } {
	    set solution $Contest/problems/$Problem/[ set ${prob}::Program ] 
	} else {
	    set solution ""
	}
    } else {
	set static_corrector ""
    }

    if [ info exists ${prob}::Dynamic_corrector ] {
	set dynamic_corrector [ set ${prob}::Dynamic_corrector ]
    } else {
	set dynamic_corrector ""
    }
    if { [ info exists ${prob}::Environment ] } {
	set environment $Contest/problems/$Problem/[ set ${prob}::Environment ] 
    } else {
	set environment ""
    }


    set errorInfo "-"
    set all_tests_dir $Contest/problems/$Problem/tests

    data::open $Contest/submissions
    set run_all_tests [ $Contest/submissions run_all_tests ]

    template::record tests_head

    set Classify   0;# using a number in tests, by default is Accepted
    set Skip_tests 0;# should skip remaining tests?
    set Mark     0  ;# sum of points in each run

    if { $static_corrector != "" } {
	set Classify [ ${_Self_} static_corrector \
			   $static_corrector Observations ]
    }

    set summary_info {}

    foreach test_dir [ lsort [ glob -nocomplain -type d $all_tests_dir/* ] ] {

	set test [ file tail $test_dir ]
	contest::remove_usage_file	;# make sure it is not in the way

	foreach {mark classify observations} \
	    [ ${_Self_} run_single_test $test_dir $Program $dynamic_corrector ]\
	    {}
	incr Mark $mark
	lappend summary_info $classify $observations $test_dir
	if { ! $run_all_tests && $Skip_tests } {
	    template::record tests_skip
	    break
	}
    }

    template::record tests_foot
    contest::remove_usage_file

    set Classify	[ lindex $Results $Classify ]

    return $summary_info
}

## Executes a given test with this submission
Operation Submission::run_single_test {test file corrector} {
    global errorInfo
    global errorCode
    variable ::Language::ErrorMessage
    variable Param
    variable Results
    variable Sub
    variable Service

    set message ""
    set td	[ data::open $test ] 

    foreach {var isPathname} { input 1 output 1 context 1 args 0 } {
	if [ info exists ${td}::$var ] {
	    if $isPathname {
		set $var	$test/[ set ${td}::$var ]
	    } else {
		set $var	[ set ${td}::$var ]
	    }
	} else {
	    set $var ""
	}
    }

    if { 
	[ info exists ${td}::Points ] && 
	[ regexp {^\d+$} [ set ${td}::Points ] ] 
    } {
	set mark [ set ${td}::Points ] 
    } else {
	set mark 0
    }

    set classify_code	0
    set observations    ""

    set expected [ file::read_in $output ]
    set obtained [ $Sub(language) execute \
		       ${_Self_} $file $args $context $input Param ]

    contest::parse_usage Usage
    ${_Self_} classify_run $expected $obtained Usage classify_code

    if { $corrector != "" } {
	set classify_code [ ${_Self_} dynamic_corrector $corrector message ]
    }

    if { $classify_code > $Classify } {
	set Classify  $classify_code
	if { $errorInfo != "" } {
	    set Observations [ set observations "$ErrorMessage" ]
	    #set Observations "(test [ file tail $test ]): $ErrorMessage"
	}
    }

    if { $classify_code == 0 } {
	set classify ""
    } else {
	set classify [ lindex $Results $classify_code ]
	if { ! $Service } {
	    layout::color classify red
	}
	set mark 0
    }    

    if { $Service } {
	format_output_service
    } else {
	format_output_standard
    }	

    set test_name	[ file tail $test ]

    template::record test    
    if { $message != "" } {
	template::record message
    }

    return [ list $mark $classify_code $observations ]
}

proc Submission::format_output_service {} {
    upvar expected expected
    upvar difference difference
    upvar obtained obtained

    set difference [ compare::show_differences $expected $obtained ]
}

proc Submission::format_output_standard {} {
    upvar expected expected
    upvar difference difference
    upvar obtained obtained
    variable SmallOutput

    ## SHOUN'T HAVE TWO DIFFERENT TYPES OF OUTPUT !!
    set too_long [ format {<font color="orange"><i>%s</i></font>} \
		       [ translate::sentence "Output too long: truncating" ]]
    set differences_without_html_tags 1
    if { [ string length $expected ] < $SmallOutput } {
	if { [ string length $obtained ] < $SmallOutput } {
	    set difference [ compare::show_differences $expected $obtained ] 
	    set difference [ layout::show_white_chars_html $difference ]
	    set differences_without_html_tags 0
	    set obtained	[ layout::show_white_chars $obtained ]
	} else {
	    set difference [ compare::show_differences2 $expected $obtained ]
	    set obtained $too_long\n[string range $obtained 0 $SmallOutput]...
	}
	set expected   [ layout::show_white_chars $expected ]
    } else {
	set difference [ compare::show_differences2 $expected $obtained ]
	set expected $too_long\n[string range $expected 0 $SmallOutput]...
	if { [ string length $obtained ] < $SmallOutput } {	    
	    set obtained	[ layout::show_white_chars $obtained ]
	} else {
	    set obtained $too_long\n[string range $obtained 0 $SmallOutput]...
	}
    }
    if { 
	[ string length $difference ] > $SmallOutput 
	&& $differences_without_html_tags
    } {
	set difference $too_long\n[string range $difference 0 $SmallOutput]...
    }
}



##Invoke a user supplied static corrector to program source
Operation Submission::static_corrector {corrector  message_} {
    upvar 3 $message_	message
    upvar 3 solution	solution
    upvar 3 environment environment

    set vars [ list \
		   home 	[ pwd ]				\
		   program	[ pwd ]/${_Self_}/${Program}	\
		   solution	$solution			\
		   environment  $environment			\
	      ]

    return [ ${_Self_} invoke_corrector $corrector $vars message ]
}


##Invoke a user supplied dynamic corrector to classify run
Operation Submission::dynamic_corrector {corrector message_} {
    upvar 3 $message_  message
    upvar 3 output output
    upvar 3 obtained obtained

    set vars [ list \
		   home 	[ pwd ]				\
		   program	[ pwd ]/${_Self_}/${Program}	\
		   expected	$output
		  ]
    foreach var {input args context classify_code} {
	upvar 3 $var $var
	lappend vars $var [ set $var ]
    }

    set obtained_file [ pwd ]/${_Self_}/.obtained
    set fd [ open $obtained_file w ] 
    puts $fd $obtained
    catch { close $fd }

    variable ::Language::ErrorMessage
    set obtained_error_file [ pwd ]/${_Self_}/.obtained_error
    set fd [ open $obtained_error_file w ] 
    puts $fd $ErrorMessage
    catch { close $fd }
    
    lappend vars obtained $obtained_file error $obtained_error_file

    set status [ ${_Self_} invoke_corrector $corrector $vars message ]

    if { $status > 0 } {
	set message [ format {<br><font color="red">%s</font>} $message ]
    }

    return $status
}

# Invoke a corrector (either static or dynamic) with vars
Operation Submission::invoke_corrector {corrector vars message_} {
    global errorInfo 
    global errorCode

    upvar 3 $message_  message

    set env "DISPLAY=:0"
    foreach {var value} $vars {
	lappend env [ string toupper $var]=$value
    }

    set command_line [ file::expand $corrector $vars ]


    set here [ pwd ]
    cd  ${_Self_}

    if [ catch {
	set fd [ open "| env -- $env $command_line " r ]
	set output  [ read $fd 1000 ]
	close $fd
	
    } msg ] {
	cd $here
	# error $msg $errorInfo $errorCode
	set status [ lindex $errorCode 2 ]
	append output $msg
    } else {
	cd $here
	set status 0
    }

    # set special output lines as variables
    foreach line [ split $output \n ] {
	if [ regexp {Mooshak_(\w+):(.*)} $line - var value ] {
	    set $var $value
	} else {
	    append message $line\n
	}
    }
    return $status
}


## Classify a previous test run that hasn't aborted
## based on output and resource usage
Operation Submission::classify_run  {expected obtained usage_ classify_} {
    variable Param
    global errorInfo
    global errorCode
    upvar 3 $usage_ Usage
    upvar 3 $classify_ classify

    set classify     0
    if {
	$errorCode == 0 &&
	! [ string equal $obtained $expected ] } {
	if { [ string equal 		\
		   [ compare::normalize $obtained ] 	\
		   [ compare::normalize $expected ] 	\
		  ] } {
	    set classify 1		;# "Presentation Error" 
	} else {
	    set classify 2		;# "Wrong Answer"
	}
    }	

    if { $Usage(elapsed) > $Elapsed	} { set Elapsed $Usage(elapsed) }
    if { $Usage(cpu)     > $CPU		} { set CPU	 $Usage(cpu)	 }
    if { $Usage(memory)  > $Memory	} { set Memory	 $Usage(memory)  }


    #layout::alert errorCode='$errorCode'\nerrorInfo='$errorInfo'

    if { $errorCode == 0 } {
	set classify [ classify_safexec $classify ]
    } elseif { $errorCode > 0 } {
	set classify [ classify_stderr ]
    } else {
	set classify [ classify_signals ]
    }

    return $classify
}

# Use safeexec error messages to classify runs with zero exit status
proc Submission::classify_safexec {classify} {
    variable Skip_tests
    upvar Usage Usage
    upvar Param Param
    global errorInfo
    global errorCode    
    variable Service

    switch $errorInfo {
	"Memory Limit Exceeded" {
	    set classify 4		;# Memory Limit Exceeded
	    if { ! $Service } { 
		layout::color Usage(memory) red 
	    }
	    set Skip_tests 1
	}
	"Time Limit Exceeded" {
	    set classify 5		;# Time Limit Exceeded
	    
	    if { $Usage(elapsed) > $Param(RealTimeout) } { 
		if { ! $Service } { 
		    layout::color Usage(elapsed) red 
		}
		set errorInfo "Real timeout exceeded"
		append errorInfo "\n(tried to read past end of file?)"
	    } elseif { $Usage(cpu) > $Param(ExecTimeout) } {
		if { ! $Service } { 
		    layout::color Usage(cpu) red 
		}
		set errorInfo "Execution timeout exceeded"
	    }
	    
	    set Skip_tests 1
	}

	"Output Limit Exceeded" {
	    set classify 3		;# Output Limit Exceeded
	    set Skip_tests 1		
	}
	"Invalid Function"  - "Internal Error" {
	    set classify 6		;# Invalid Function
	}
    }
    return $classify
}

# Use stderr to classify runs with exit status
proc Submission::classify_stderr {} {
    variable Skip_tests
    upvar Usage Usage
    upvar Param Param
    global errorInfo
    global errorCode    
    variable Service

    switch -regexp $errorInfo {
	OutOfMemoryError {
	    set classify 4		;# Memory Limit Exceeded
	    if { ! $Service } { 
		layout::color Usage(memory) red 
	    }
	    set Skip_tests 1
	}
	{^$} {
	    # trap return 1 and similar cases

	    # working TOO well (may conflict with Free Pascal return codes)
	    # set classify 6		;# Invalid Function

	    set classify 7	;# Runtime Error
	    set errorInfo "Invalid exit value: $errorCode"
	}
	default {
	    set classify [ classify_default ]
	}
    }
    return $classify
}

# Use signals to classify runs 
proc Submission::classify_signals {} {
    variable Skip_tests
    global errorInfo
    global errorCode    

    if { 
	$errorCode == -13 && 
	[ string length $obtained ] > $Param(MaxOutput) 
    } {
	#received a SIGPIPE (pipe closed before reading) 
	# and ouput limit exceeded 
	
	set classify 3		;# Output Limit Exceeded
	set Skip_tests 1
    } else  {
	set classify [ classify_default ]
    }
    return $classify
}


proc  Submission::classify_default {} {
    variable Skip_tests
    global errorInfo
    global errorCode    
    
    if [ contest::requires_reevaluation $errorInfo ] {
	set classify 11	;# Requires Reevaluation
    } else {
	set classify 7	;# Runtime Error
    }	    
    return $classify
}


#-----------------------------------------------------------------------------
# Operations used in listings aggregating submissions

## Show a line in submissions listing
Operation Submission::listing_line {n m profile 
    {give_feedback ""} 
    {show_errors {}}
    {show_own_code 1}
} {
    variable Contest
    variable MaxLabelSize
    variable ::Submission::Results
    variable ::Submission::States


    ${_Self_} set_contest
    set sub [ file tail ${_Self_} ]    

    layout::toggle_color m color

    # some integrity checks
    foreach var { Time Team Classify Problem } {
	if { ! [ info exists $var ] || [ set $var ] == "" } {
	    # layout::alert $var:[ set $var ] ;# do not report 
	    template::write empty
	    return
	}
    }

    data::open $Contest/groups

    foreach {group_color group_flag group_acronym team_name team_qualifies} \
	[ $Contest/groups identify $Team 				    \
	      {Color Flag Acronym} 					    \
	      {Name Qualifies} ] {} 
    
    set team_name [ layout::fit_label $team_name $MaxLabelSize ]

    set state		$State

    set hour [ date::format $Time $Date ] 

    switch $give_feedback {

	none {
	    set classify [ translate::sentence "Received" ]
	}
	{} - classification - report - all {
	    set classify	$Classify
	    layout::color classify \
		[ expr [lsearch $Results $Classify] == 0 ?"green":"red" ]


	    if { $Mark != "" } {
		set classify [ format {%s %s} $Mark $classify ]
	    }
	}
    }

    if { [ lsearch $States	$State		] == 0 } {
	set state <b>$state</b>
    } else {
	layout::color state gray
    }

    switch $team_qualifies {
	no		{ set dest B }
	yes - default	{ set dest N }
    }

    if [ string equal $Problem - ] {
	# Quiz (no problem  set)
	set problem_name Quiz
	set problem_color "black"
	set problem_descriprion $Report
    } else {
	set prob [ data::open $Contest/problems/$Problem ]
	set problem_name [ set ${prob}::Name ]
	set problem_color [ set ${prob}::Color ]
	set problem_description [ set ${prob}::Description ]
    }
    if  [ regexp {^admin|judge$} $profile ] {
	template::write sub:root 
    } else {
	if { 
	    [ contest::with_team ] &&
	    [ string equal $Team [ contest::team ] ] 
	} {
	    ${_Self_} my_line $sub $give_feedback $show_errors
	    
	    if $show_own_code {
		template::write sub:mine  
	    } else {
		template::write sub:lin
	    }
	} else {
	    template::write sub:lin   
	}
    }
}

# if it's my submission I can download it and get feedback on my errors
Operation Submission::my_line {sub give_feedback show_errors} {
    upvar 3 fx fx
    upvar 3 classify classify

    set sub [ file tail ${_Self_} ]    
    set fx [ file tail $sub ]

    if { [ lsearch $show_errors $Classify ]  > -1} {
	switch $give_feedback {
	    all {
		variable ::Session::Conf
		set format {<a href="%s">%s</a>}

		set url $Conf(controller)/execute?report+$sub+""
		set classify [ format $format $url $classify ]

	    }
	    report {
		if { $Feedback != "" } {
		    variable ::Session::Conf
		    
		    set format {<a href="%s">%s</a>}
		    upvar 3 n n
		    set url $Conf(controller)/execute?feedback+$sub+$n
		    set classify [ format $format $url $classify ]
		}
	    }
	    classification {
		if { $Observations != "" } {
		    set format \
			{<a class="Clickable" onClick="alert('%s')">%s</a>}
		    set classify [ format $format 			     \
				       [ layout::protect_js $Observations ]  \
				       $classify ]
		}
	    }
	}
    }
}

#------------------------------------------------------------------------------
# Other procedures




## Return list of possible states 
## (Workaround: could not refer to variable during pkg_mkIndex in Submission)
proc Submission::get_states {} {
    variable States

    return $States
}
