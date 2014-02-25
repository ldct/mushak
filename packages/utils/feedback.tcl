#
# Mooshak: managing programming contests on the web		September 2008
# 
#			Zé Paulo Leal 		
#			zp@dcc.fc.up.pt
#
#-----------------------------------------------------------------------------
# file: feedback.tcl
# 
## Feedback to users based on a list of triplets 
##  Classifications Observations test_dir
## for each run
## 

package provide feedback 1.0

namespace eval feedback {
    variable Types {
	worst_classification_observation
	count_worst_classification
	all_classifications_observations
	count_classifications
	test_case_feedback_hint
	test_case_input_result
	test_case_input_output
    }

    variable Format	;# Format strings

    
    foreach {key message} {
	input-output	"The input <pre>%s</pre> should return <pre>%s</pre>"
	input-result 	"The input <pre>%s</pre> produces <b>%s</b>"
	hint		"Hint: <pre>%s</pre>"
	count		"%2d tests with <b>%s</b>"
	count-1		"1 test with <b>%s</b>"
	observation	"Observation of <b>%s</b> <pre>%s</pre>"
    } {
	set Format($key) [ translate::sentence $message ]
    }
	

}

proc feedback::default_summary { summary_info } {
    variable Types

    set default_type [ lindex $Types 0 ]
    return [ lindex [ ${default_type}_summary $summary_info ] 0 ]
}


## Summarizes given info, avoiding repetions of feedback for same problem/team
## as recorded submissions
proc feedback::summarize { submissions problem team summary_info } {
    variable Types

    set feedback {}

    set breaking 0 ;# tcl doesn't have multi-level breaks
    foreach type $Types {

	foreach message [ ${type}_summary $summary_info ] {

	    # ignore empty message (message was senseless and was aborted)
	    if { $message == "" } continue
	    # ignore repeated messages
	    if { [ lsearch $feedback $message ] > -1 } continue
	    
	    lappend feedback $message

	    # check if message gives incremental feedback
	    if { [ $submissions fresh_feedback $team $problem $feedback] } {

		set breaking 1
		break	
	    }
	}
	if $breaking break
    }

    return $feedback
}


## Sepecial version of sumurize for the evaluation service
## Returns all feedback at once (non-incremental)
proc feedback::summarize_service { problem team summary_info } {
    variable Types

    set feedback {}

    foreach type $Types {

	foreach message [ ${type}_summary $summary_info ] {

	    # ignore empty message (message was senseless and was aborted)
	    if { $message == "" } continue
	    # ignore repeated messages
	    if { [ lsearch $feedback $message ] > -1 } continue
	    
	    lappend feedback $type $message
	}
    }

    return $feedback
}



## ---------------------------------------------------------------------
## 
## Procedures with "_summary" as sufix receive a list of triplets
##	classify
##	observations
## 	test_case_dir
## implement a different for summarizing this data into a message
## and return a list a alternative summary messages
##
## ---------------------------------------------------------------------

## Returns selected input files associated with non-acccepted test cases
#
proc feedback::test_case_input_output_summary { summary_info } {
    variable ::Submission::Results
    variable Format

    set summary {}
    foreach { classify observations dir } $summary_info {
	switch $classify {
	    1 - 2 - 4 - 5 - 6 - 7 {
		set seg [ data::open $dir ]

		variable ${seg}::Show
		variable ${seg}::input
		variable ${seg}::output

		if { 
		    [ info exists Show ] 		&& 
		    [ string equal $Show "yes" ]	&&
		    [ info exists input ] 		&& 
		    [ file readable $dir/$input ]	&&
		    [ info exists output ] 		&& 
		    [ file readable $dir/$output ] 
		} {
		    set input_example  [ file::read_in $dir/$input ]
		    set output_example [ file::read_in $dir/$output ]
		    lappend summary [ format $Format(input-output) \
					  $input_example $output_example ]
		}
	    }
	}
    }

    return $summary    
}



## Returns selected input files associated with non-acccepted test cases
#
proc feedback::test_case_input_result_summary { summary_info } {
    variable ::Submission::Results
    variable Format

    set summary {}

    foreach { classify observations dir } $summary_info {
	switch $classify {
	    1 - 2 - 4 - 5 - 6 - 7 {
		set seg [ data::open $dir ]


		variable ${seg}::Show
		variable ${seg}::input

		if { 
		    [ info exists Show ] 		&& 
		    [ string equal $Show "yes" ]	&&
		    [ info exists input ] 		&& 
		    [ file readable $dir/$input ] 
		} {

		    set classify_text \
			[ translate::sentence [ lindex $Results $classify ] ]
		    set example [ file::read_in $dir/$input ]
		    lappend summary [ format $Format(input-result) $example \
					 $classify_text ]
		}
	    }
	}
    }

    return $summary    
}



## Returns non-empty feedback messages associated with non-acccepted test cases
#
proc feedback::test_case_feedback_hint_summary { summary_info } {
    variable Format    

    set summary {}
    foreach { classify observations dir } $summary_info {
	switch $classify {
	    1 - 2 - 4 - 5 - 6 - 7 {
		set seg [ data::open $dir ]
		
		variable ${seg}::Feedback
		
		if { [ info exists Feedback ] && $Feedback != "" } {
		    lappend summary [ format $Format(hint) $Feedback ]
		}
	    }
	}
    }
    return $summary
}


## Number of classifications of each type, ordered by descending frequency
## ex. 3 tests with Wrong answer \n 2 tests with Time Limit Exceeded
proc feedback::count_classifications_summary { summary_info } {

    variable ::Submission::Results
    variable Format    

    set ntests 0
    foreach {classify -  - } $summary_info {
	etc::increment count($classify) 
	incr ntests
    }

    # this summary makes no sence with just one test case
    if { $ntests == 1 } { return {}  }    


    set summary {}
    foreach classify [ orded_names count ] {

	set classify_text \
			[ translate::sentence [ lindex $Results $classify ] ]

	if { $count($classify) == 1 } {
	    lappend summary [ format $Format(count-1) $classify_text ]	 
	} else {
	    
	    lappend summary [ format $Format(count) $count($classify)	\
				  $classify_text ]
	}
    }
    
    return [ list [ join $summary \n ] ]

}

## Number of classifications of each type, ordered by descending frequency
## ex. 3 tests with Wrong answer \n 2 tests with Time Limit Exceeded
proc feedback::count_worst_classification_summary { summary_info } {
    variable ::Submission::Results
    variable Format

    set ntests 0
    set worst  0
    set observ($worst) ""
    set count($worst) 0
    foreach {classify observations - } $summary_info {
	etc::increment count($classify) 
	set observ($classify) $observations
	if { $classify > $worst } {
	    set worst $classify
	}
	incr ntests
    }

    # this summary makes no sence with just one test case
    if { $ntests == 1 } { return {} }    

    set classify_text \
	[ translate::sentence [ lindex $Results $worst ] ]


    if { $count($worst) == 1 } {
	set summary [ format  $Format(count-1) $classify_text ]
    } else {

	set summary [ format $Format(count) 				\
			  $count($worst) $classify_text  ]
    }
    
    return [ list $summary ]

}


## Other observations (higher severity)
proc feedback::all_classifications_observations_summary { summary_info } {
    variable Format
    variable ::Submission::Results
    
    set summary {}
    foreach { classify observations - } $summary_info {
	if { $observations == "" } continue

	set class [ translate::sentence [ lindex $Results $classify ] ]
	set message [ format $Format(observation) $class $observations ]
	if { [ lsearch $summary $message ] > -1 } {
	    lappend summary $message
	}
    }
    return [ list [ join $summary "<br/>" ] ]
}


## Observations of worst classification (higher severity)
proc feedback::worst_classification_observation_summary { summary_info } {
    variable Format
    variable ::Submission::Results

    set worst 0
    set observ($worst) ""
    foreach { classify observations - } $summary_info {
	set observ($classify) $observations
	if { $classify > $worst } {
	    set worst $classify
	}
    }

    set class [ translate::sentence [ lindex $Results $worst ] ]

    if { $observ($worst) == "" } {
	return [ list {} ]
    } else {
	return [ list [ format $Format(observation) $class $observ($worst) ] ]
    }
}



proc feedback::orded_names {v_} {
    upvar $v_ v 

    return [ lsort -command {feedback::cmp_array v} [ array names v ] ]
}


proc feedback::cmp_array {v_ a b} {
    upvar $v_ v

    return [ expr $v($a) > $v($b) ]
}

