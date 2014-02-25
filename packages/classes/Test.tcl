#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Test.tcl
# 
## Element of a test vector

package provide Test 1.0

namespace eval Test {
        variable Tip	;# Tips on fields content and commands

    array set Tip {
	args		"Arguments passed to the tested program"
	input	  	"File containing input for this test"
	output  	"File containing expected output"
	context		"File available for dynamic evaluators"
	Points		"Points if this test is passed (integer)"
	Feedback	"Use this message as feedback when reporting errors"
	Show		"Show this input/output files when reporting errors"
    }
}

Attributes Test {
    Fatal	fatal	{}
    Warning	warning {}        

    args	text	{}
    input	fx	{}
    output	fx	{}
    context     fx      {}

    Points	text	{}
    Feedback	text	{}
    Show	menu	{ yes no }
}

Operation Test::_update_ {} { 
    check::reset Fatal Warning

    check::attribute Fatal input  fx
    check::attribute Fatal output fx

    if { ! [ regexp {^\d*$} $Points ] } {
	append Fatal "Points should be a positive integer and not $Points\n"
    }

    append Warning [ check_file_content ${_Self_} $input $output ]


    return [ check::requires_propagation $Fatal ] 
}


# Checks this directories and its descendants
Operation Test::check {} {
    
    check::dir_start
    check::vars input output
    check::fxs input output
    check::sub_dirs
    check::dir_end
}

## Cleanup eol characters in test files
Operation Test::cleanup ! {
    
    foreach file [ list $input $output ] {
	set fx ${_Self_}/$file
	if { ! [ file readable $fx ] } continue
	set data [ file::read_in $fx ]
	if { ! [ file writable $fx ] } {
	    layout::alert "File $file not writable"
	    continue
	}

	# trim white chars from data files
	set data [ string trim $data "\ \n\t" ]
	# trim spaces and tabs before end-of-line
	regsub -all "(\ |\t)+\n" $data "\n" data
	# trim spaces and tabs after end-of-line
	regsub -all "\n(\ |\t)+" $data "\n" data
	# replace consecutive spaces by a single one
	regsub -all "\ \ +" $data "\ " data


	set fd [ open $fx w ]
	puts -nonewline $fd $data
	catch { close $fd }
    }
    layout::alert "file cleaned up"
    content::show ${_Self_}
}

## Serialize this directory as a tcl data structure
## DEPRECATED
Operation Test::out {} {

    set id [ file tail ${_Self_} ]
    set children [ list [ list input [ list src ${_Self_}/$input ] {} ] [ list output [ list src ${_Self_}/$output ] {} ] ]
    return [ list test [ list id $id ] $children ]
}


## look for funny characters in test files
proc Test::check_file_content {dir args} {
    variable ::Session::Conf

    set msg ""

    set errors {}
    foreach file $args {
	if [ file readable $dir/$file ] {
	    set data [ file::read_in $dir/$file binary ]
	    
	    if [ regexp "(\r\n|\n\r)" $data ] {
		lappend errors "non unix end-of-line characters<br>"
	    }
	    
	    if [ regexp  "(\ |\t)+\n" $data ] {
		lappend errors "spaces or tabs ending lines<br>"
	    }
	    
	    if [ regexp  "^\n+" $data ] {
		lappend errors "empty lines in the beginning<br>"
	    }

	    if [ regexp  "\ \ +" $data ] {
		lappend errors "consecutive spaces<br>"
	    }
	    
	    if [ regexp  "\n(\ |\t)+" $data ] {
		lappend errors "spaces or tabs starting lines<br>"
	    }
	    
	    if [ regexp  "\n(\w|\n)+$" $data ] {
		lappend errors "empty lines in final<br>"
	    }
	    	    
	} else {
	    append msg "File $file not readable<br>"
	}

    }

    if { $errors != {} } {
	set url $Conf(controller)?operation+cleanup+$dir
	append msg "Consider <a target='_parent' href='$url'>"
	append msg " cleaning up test files</a> since they have"
	append msg "<ul><li>[ join $errors <li> ]</ul>"
    }


    return $msg
}
