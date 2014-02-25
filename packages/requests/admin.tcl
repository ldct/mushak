#
# Mooshak: managing  programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: admin.tcl
# 
## Requests from admin (and judge)
##


package provide admin 1.0

namespace eval admin {

}

## Toplevel admin window
proc admin::admin {} {

    template::load
    template::write
}


## Send a message to an object
##  WARNING: This is a UNSAFE command
proc admin::message args {
    variable ::Session::Conf
    
    if [ string equal admin $Conf(profile) ] {	;# double checking
	data::open [ lindex $args 0 ]
	eval $args
    } else {
	execute::report_error "Invalid Profile"
    }
}

## This is a sepecial case of message
##  WARNING: This is a UNSAFE command
proc admin::operation {operation dir} {
    data::open $dir

    puts [ $dir $operation ? ]
}


## Displays the content of a file with the appropriate mime type
## WARNING: This is a UNSAFE command 
proc admin::file {file} {

    if [ ::file readable $file ] {
	
	set fd [ open $file r ]		
	
	puts "Content-type: [ email::mime $file ]"
	puts ""
	fconfigure $fd -translation binary
	fconfigure stdout -translation binary
	fcopy $fd stdout
	close $fd
	
    } else {
	
	puts "Content-type: text/HTML"
	puts ""
	
	execute::report_error "file unreadable" $file
    }
}



## Processes form that sends a warning on the questions' listing
proc admin::warn {} {

    set contest [ contest::active_path ]
    
    data::open $contest/problems 

    set button_names { submit reset }	;# button names
    set problems [ $contest/problems selector_radio ]

    set Team ""

    template::load
    template::write 
}

## Processes a warning
proc admin::warned {} {

    set team ""
    set problem	[ cgi::field problem "" ]

    set dir [ contest::transaction questions $problem $team ]
    set sub [ data::new $dir Question ]

    data::open $dir
    $dir warned
    data::record $dir

    layout::redirect listing?command=questions
}


## DEPRECATED ?
proc admin::confirm {message command} {

    template::load confirm.html
    template::write 
}

##  WARNING: This is a UNSAFE command
proc admin::undo {dir} {

    backup::recover $dir 0

    content::show $dir 1    
}

##  WARNING: This is a UNSAFE command
proc admin::redo {dir} {

    backup::recover $dir 1

    content::show $dir 1    
}
