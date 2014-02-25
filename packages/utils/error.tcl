#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: error.tcl
# 
## Error processing

package provide error 1.0

namespace eval error {
    namespace export report	;## Reports an error to the user
    namespace export record	;## Records an unexpected occurrence
    
}


## Reports an error to the user
proc error::report {message {value ""}} {
    global errorInfo

    set message [ translate::sentence $message ]
    record [ format {%s: %s} $message $value ]
    set message [ format {%s: <code>%s</code>} $message $value ]
    template::load report_error.html
    if { $errorInfo != "" } {
	layout::alert $errorInfo
    }
    template::write

    exit
}

## Records an unexpected occurrence (probably an error)
proc error::record {message} {


    if { [ contest::with_team ] } {
	set team [ contest::team ]
    } else {
	set team ?
    }
    set contest [ contest::active_path ]

    # select an output stream
    set fd stdout
    foreach path [ list $contest/error_log data/error_log ] {
	if { 
	    (   [file exists $path] && [file writable $path] ) ||
	    ( ! [file exists $path] && [file writable [file dirname $path]] )
	} {
	    set fd [ open $path a ]
	    break
	} 
    }
    
    set date [ clock format [ clock seconds ] -format {%Y/%m/%d %H:%M:%S} ]
    puts $fd "$date $team: $message"  

    if { ! [ string equal stdout $fd ] } {
	catch { close $fd }	   
    }

}
