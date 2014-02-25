#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Problem.tcl
# 
## Managing a problem in a problem seta

package provide Problem 1.0

package require data

namespace eval Problem {
    variable Hard_timeout 	60	;# timeout used in tuning timeouts
    variable Output_file	output	;# name of output file in test vectors
    variable MaxOutputSize	20	;# max output shown in program test

    # workaround a bug do GCC
    global env;    set env(HOME) ""


    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Name		"Problem Id - a single character"
	Color		"Ballon color"
	Title		"Problem title as in the problem description"
	Type		"Type of problem"
	Description 	"Problem HTML description"
	PDF		"Problem description in PDF format"
	Program		"Source code of problem solution"
	Environment	"File with environment for compilation"
	Static_corrector	"Command line for static corrector"
	Dynamic_corrector	"Command line for dynamic corrector"
	Start		"Activate problem only at this moment"
	Stop		"Deactivate after this moment"

	Timeout		"Real time timeout in seconds"
    }

    array set Help {
	Static_corrector  {
	    A static corrector is an external program that is invoked
	    before dynamic correction to classify/process the program's
	    source code. In this field you can write a command line 
	    to invoke a static corrector and you may use these variables:

	    $home              - Mooshak's home director
	    $program          - absolute pathname of file with submitted program
	    $solution          - absolute pathname of problem solution file
	    $environment   - absolute pathname of environment data file

	    The values of these variables will also be available to the
	    process as environment variables with the same names in capitals. 
	    For instance, the command line variable $home will be available
	    as as the environment variable HOME

	    The special corrector must return the new classification
	    as its exit code. The correspondence between exit values and 
	    classifications is the following:

	      0 - Accepted
	      1 - Presentation Error		
	      2 - Wrong Answer
	      3 - Output Limit Exceeded
	      4 - Memory Limit Exceeded
	      5 - Time Limit Exceeded
	      6 - Invalid Function
	      7 - Runtime Error
	      8 - Compile Time Error
	      9 - Invalid Submission
	    10 - Program Size Exceeded
	    11 - Requires Reevaluation
	    12 - Evaluating

	    
	}

	Dynamic_corrector  {
	    A dynamic corrector is an external program that is invoked
	    after Mooshak's correction to classify each run. In this field 
	    you can write a command line to invoke a dynamic corrector
	    and you may use these variables:

	    $home             - Mooshak's home director
	    $program         - absolute pathname of file with submitted program
	    $input              - absolute pathname of input data file
	    $expected        - absolute pathname of file with expected output
	    $obtained         - absolute pathname of file with obtained output
	    $error              - absolute pathname of file with obtained error output
	    $args               - command line arguments
	    $context          - absolute path name of context file
	    $classify_code  - (integer) current classification on Mooshak

	    The values of these variables will also be available to the
	    process as environment variables with the same names in capitals. 
	    For instance, the command line variable $classify will be available
	    as as the environment variable CLASSIFY_CODE

	    The special corrector must return the new classification
	    as its exit code, i.e. the new value for CLASSIFY_CODE. The 
	    correspondence between exit values and classifications is the 
	    following:

	      0 - Accepted
	      1 - Presentation Error		
	      2 - Wrong Answer
	      3 - Output Limit Exceeded
	      4 - Memory Limit Exceeded
	      5 - Time Limit Exceeded
	      6 - Invalid Function
	      7 - Runtime Error
	      8 - Compile Time Error
	      9 - Invalid Submission
	    10 - Program Size Exceeded
	    11 - Requires Reevaluation
	    12 - Evaluating


	    
	}
    }

}

Attributes Problem {
    Fatal	fatal	{}
    Warning	warning {}        

    Name	menu	{A B C D E F G H I J K L M N O P Q R S T U V X Y W Z}
    Color	text	{}
    Title	text	{}
    Difficulty  menu	{ "Very Easy" "Easy" "Medium" "Difficult" "Very Difficult" } 
    Type	menu	{sorting graphs geometry combinatorial strings mathematics ad-hoc}
    Description	fx	{.html}

    PDF		fx	{.pdf}
    Program	fx	{}    
    Environment fx	{}
    Timeout	text	{}
    Static_corrector	text	{}
    Dynamic_corrector	text	{}
    Original_location	warning	{}

    images	dir	Images
    tests	dir	Tests

    Start	date	{}
    Stop        date	{}
}


Operation Problem::_update_ {} {

    check::reset Fatal Warning

    check::attribute Fatal Name
    check::attribute Fatal Title
    check::attribute Warning Color
    check::attribute Fatal Timeout {^\d+$}
    check::attribute Fatal Description fx
    check::attribute Fatal Start {^\d*$}
    check::attribute Fatal Stop {^\d*$}
    check::attribute Warning Program fx
    check::attribute Fatal tests dir

    return [ check::requires_propagation $Fatal ]

}


## Checks vars and sub directories
Operation Problem::check {} {
    
    check::dir_start
    check::vars Name {Timeout {^[1-9]\d*$} } ;# cannot be 0 
    check::fxs Description Program
    check::sub_dirs
    check::dir_end
}

## Number of seconds from start of contest after which this problem is shown
Operation Problem::start {} {
    
    if { [ info exists Start ] && [ regexp {^\d+$} $Start ] } {
	set contest [ contest::active_path ]
	return [ $contest adjust_time $Start ]
    } else {
	return 0
    }
}

## Number of seconds from start of contest after which this problem is shown
Operation Problem::stop {} {
    
    if { [ info exists Stop ] && [ regexp {^\d+$} $Stop ] } {
	set contest [ contest::active_path ]
	return [ $contest adjust_time $Stop ]
    } else {
	return [ expr inf ]
    }
}


## Test the program against test cases
Operation Problem::test-solution ! {

    ${_Self_} test 0

    content::show ${_Self_}    
}

## Generate outputs for the current test vector
Operation Problem::generate-outputs ! {

    ${_Self_} test 1
    
    content::show ${_Self_}    
}


## Check/Generate outputs for all inputs in the test vector
Operation Problem::test {{create_outputs 1}} {
    variable Hard_timeout

    if { $Program == "" && ! [ info exists ${_Self_}/$Program ] } { 
	layout::alert  "Missing program file" ${_Self_}/$Program test
	return 
    }

    set languages [ file::canonical_pathname ${_Self_}/../../languages ]

    data::open $languages
    array set Param [ $languages params ]
    if { [ set language [ $languages search $Program] ] != {} } {
	set lang [ data::open $language ]
	set Language  [ set ${lang}::Name ]
    } else {
	layout::alert "Invalid language" $Program test
	return
    }

    array set param [ $languages params ]
    

    # compiles program and checks errors
    set problem [ file tail ${_Self_} ]
    if { [ catch {
	$language compile ${_Self_} $Program $problem param
    } msg ] } {
	# "compile time error"

	layout::alert "Compilation error" $msg test
	return
    }

    set max_time 0
    foreach test [ glob -nocomplain -types d ${_Self_}/tests/* ] {
	${_Self_} test_single_case $test $language $create_outputs

    }

    set timeout [ expr $max_time + 1 ]
    if { ! [ string equal -nocase $language java ] } {
	set timeout [ expr $timeout * 2 ]
    }

    layout::alert test "MaxTime=$max_time Timeout=$timeout"

}

## Check/Generate outputs for a single test case
Operation Problem::test_single_case {test language create_outputs} {
    variable Output_file
    variable MaxOutputSize

    upvar 3 max_time	max_time
    upvar 3 param	param

    set st     [ data::open $test ]
    
    foreach var { input output args context } {
	if [ info exists ${st}::$var ] {
	    set $var  [ set ${st}::$var ]
	} else {
	    set $var ""
	}
    }
    
    if { [ file readable $test/$input ] } {
	set start [ clock seconds ]
	if { [ catch { 		
	    set fx [pwd]/$test/$input
	    set obtained [ $language execute ${_Self_} $Program \
			       $args $context $fx param ]	    
	} msg ] } {
	    layout::alert $test "Execution error" $msg
	    return
	}
	contest::parse_usage Usage
	global errorCode errorInfo
	if { $errorCode != 0 } {
	    layout::alert $errorCode:$errorInfo
	    # layout::alert [ file::read_in [ contest::usage_file ] ]
	}

    } else {
	layout::alert $test "Cannot read input file" $test/$input
	return
    }
    
    if $create_outputs {
	
	set fw [ open $test/$Output_file w ]
	puts -nonewline $fw $obtained
	catch { close $fw }
	
	
	set duration [ expr [ clock seconds ] - $start ]
	if { $duration > $max_time } {
	    set max_time $duration 
	}
	
	
	set tst [ data::open $test ]
	set ${tst}::output $Output_file
	data::record $test
	
    } else {
	
	set duration [ expr [ clock seconds ] - $start ]
	if { $duration > $max_time } {
	    set max_time $duration 
	}
	
	if { [ file readable $test/$output ] } {
	    set that [ file::read_in $test/$output ]
	    
	    if { ! [ string equal $obtained $that ] } {

		set message "Wrong output"
		set what [ layout::truncate_label $that $MaxOutputSize]
		append message [ format "\nexpected: %s" $what ]
		set what [ layout::truncate_label $obtained $MaxOutputSize]
		append message [ format "\nobtained: %s" $obtained ]
		layout::alert $test $message
	    }
	} else {
	    layout::alert $test "Cannot read file" $test/$output
	}
	
    }
}

