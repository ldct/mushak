#
# Mooshak: managing programming contests on the web		May 2004
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: state.tcl
# 
## state management for HTTP interfaces
##
## This package manages state info associated web browsers.
## Each session has a unique relative path with the Mooshak application
## to allow different sessions in a single web browser.
## With this aproach the (few) cookies needed to keep state information 
## in a browser are not mixed. This package relies on State persistant objects



package provide state 1.0

package require data
package require Session

namespace eval state {


    variable Cookies		;## Vars saved in cookies
    variable StateCookies	;## State vars saved in cookies
    variable ApplicationCookies	;## Application vars saved in cookies


    set StateCookies 		{ session authorization contest }
    set ApplicationCookies 	{ browser }
    set Cookies 		[ concat $StateCookies $ApplicationCookies ]
}




## Write cookies header lines to preserve session data in browser.
## Starts by copying CGI variables to session configuration
## and invoking state handling procedure in package (if defined) to give
## each package a chance to change state it necessary.
proc state::process_cookies {package command} {
    variable StateCookies
    variable ApplicationCookies
    variable ::Session::Conf
    variable ::cgi::Field
    global env 

    foreach var [ array names Conf ] {	
	if { [ cgi::field $var "" ] != "" } {
	    set Conf($var) $Field($var)
	}
    } 
    set Conf(command) $command

    # give a chance to process commands before completing headers
    if { [ info procs ::${package}::_state_ ] != "" } {
	::${package}::_state_
    }


    if { ! [ info exists Conf(browser) ] || $Conf(browser) == "" } {
	set Conf(browser) [ password::generate ]
	send_cookies $ApplicationCookies /
    } 
	 
    if [ regexp {^(.*/\d+)((\?|\+).*)?$} $env(REQUEST_URI) - path ] {
	send_cookies $StateCookies $path
    }
	 
}

## Send cookies to browser associated with path
proc state::send_cookies {cookies path} {
    variable ::Session::Conf
    
    foreach c $cookies {
	if [ info exists Conf($c) ] {
	    set cookie(mooshak:$c) $Conf($c)
	}
    }
    
    cgi::record_cookies cookie
    cgi::write_cookies $path
}

