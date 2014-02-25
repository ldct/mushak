#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: utils.tcl
# 
## Utilities

package provide utils 1.0

namespace eval utils {
    namespace export increment		;# increments (and defines) a variavel 


    namespace export unique    		;# unique elements of list

}




## Returns the value (if defined) of a CGI variable.
## A default value can be provided for undefined variables.
proc cgi::field args {

    if { [ llength $args ] < 1 }  {
	execute::report_error "Undefined variable name"
    } else {
	set var [ lindex $args 0 ]
    }
    if [ info exists cgi::Field($var) ] {
	if { $cgi::Field($var) == "" && [ lindex $args 1 ] != "" } {
	    execute::report_error "Field required" $var
	} else {
	    return $cgi::Field($var)	    
	}
    } else {
	if { [ llength $args ] < 2 } {
	    execute::report_error "Variable undefined without default value" $var 

	} else {
	    return [ lindex $args 1 ]
	}
    }
}

## Is there a team (a CGI user)?
proc contest::with_team {} {
    global env

    return [ info exists ::env(REMOTE_USER) ]
}

## Returns the name of the team (the CGI user).
proc contest::team {} {
    global env

    if { [ info exists env(REMOTE_USER) ] } {
	return $env(REMOTE_USER)
    } else {
	execute::report_error "Unidentified team" 
    }
}


## Reports an error to the user
proc execute::report_error {message {value ""}} {
    global REL_BASE

    set message [ translate::sentence $message ]
    record [ format {%s: %s} $message $value ]
    set message [ format {%s: <code>%s</code>} $message $value ]
    template::load execute::report_error.html
    template::write

    exit
}

## Records an unexpected occurrence (probably an error)
proc execute::record_error {message} {
    global env


    if { [ info exists ::env(REMOTE_USER) ] } {
	set team $env(REMOTE_USER)
    } else {
	set team ?
    }

    foreach path { data/contest/error_log data/error_log stdout } {
	if [ catch { set fd [ open $path a ] } ] continue else break
    }
    
    set date [ clock format [ clock seconds ] -format {%Y/%m/%d %H:%M:%S} ]
    puts $fd "$date $team: $message"  
    catch { close $fd }	   

}


## Returns the given list with duplicated elements removed
proc etc::unique {l} {

    set n {}
    foreach e $l {
	if { [ lsearch $n $e ] == -1 } {
	    lappend n $e
	}
    }
    return $n
}


## Increments a variable, inicializing it if needed
proc etc::increment {var_} {
    upvar $var_ var

    if [ info exists var ] {
	incr var
    } else {
	set var 1
    }
}

## Returns the last type of listing request by the client (usin g cookies)
proc contest::last_listing {{default pending}} {
    global env

    if { 
	[ info exists env(HTTP_COOKIE) ] && 
	[ regexp {command=([a-z]+)} $env(HTTP_COOKIE) - listing ] 
    } {
	
    } else {
	set listing $default
    }

    return $listing
}

