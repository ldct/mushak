#
# Mooshak: managing programming contests on the web		May 2004
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Session.tcl
# 
## Session management
##
## Basic operation over sessions are:
##	record	save Conf array to persistent session
##	recover	copy persistent session to Conf array
##
## There are a few important static procedures:
##	new 	create a new open with default values
##	init	create or recover a session and do autentication
##	close	record session and do housekeeping
##
## Requests for the same session must be serialized (this is nasty).
## Concurrent requests for the same session may have strange side effects.
## Sessions are locaked on init and unlock on close.

package provide Session 1.0

package require data

namespace eval Session {

    variable Closed 	0	;## Session was been closed
    variable Conf		;## Session configurations values
    variable ChangeableConf	;## Conf changeable by menus
    variable Preserve		;## Temporary array for changeable confs
    variable Lock session_lock	;## filename for session locks
    
    variable Default		;## default values for session fields
    variable Tip

    set KnownBrowsers 		{Firefox Mozilla Opera}

    set ChangeableConf {style language}

    array set Tip {

	profile		"User Profile"
	style		"Page style (CSS)"
	language	"User prefered language"

	user		"User ID"
	authorization	"Hash of password"
	browser		"Browser identification"
	contest		"Current Contest ID"
	command		"Command excecuted"
	messages	"Messages pending"
	modified	"time (seconds) of last mofification (submission, question)"
	
	type		"Type of listing"
	time		""
	time_type	"Type of time to display in listing"
	page		"Page number of listing"
	lines		"Lines per page in listing"
	problems	"List of problems in listings"
	teams		"List of teams in listings"

	time_interval	"Interval in evolution listings (in seconds)"
	
	words		"Words used as search term"
	flow		"Flow of search (up of down)"
	scope		"Scope of search"
	
	size		"Size of text in help pages"
	tab		"Using tab in help screen?"
	tree		"Showing tree in help screen?"
	search  	"Words used as search term in help"
	path		"Path to current help page"
	
	archive		"Prefered type of archive"

	virtual		"virtual start time"

	groups		"Groups in Quiz"
	questions	"Questions in Quiz"
	choices		"Choices in Quiz"
	
	target		"Path to directory for linking"
    }

    ## 
    ## (defaults default to the empty string :-)
    array set Default {
	profile		guest
	style		base
	language	""
	modified	0

	type		submissions
	time		5
	time_type	contest
	time_interval	900
	page		0
	lines		15
	flow		down
	scope		label
	size		0
	tab		1
	tree		0
	search  	0
    }


}

Attributes Session {

    profile		text	{}
    user		text	{}
    authorization	text	{}
    contest		text	{}
    command		text	{}
    browser		text	{}
    messages		text	{}
    modified		text	{}
    controller		text	{}
    style		text	{}
    language		text	{}

    type		text	{}
    time		text	{}
    time_type		text	{}
    page		text	{}
    lines		text	{}
    problems		text	{}
    teams		text	{}

    time_interval	text	{}

    words		text	{}
    flow		text	{}
    scope		text	{}

    size		text	{}
    tab			text	{}
    tree		text	{}
    search  		text	{}
    path		text	{}
    words		text	{}    

    archive		text	{}
    virtual 		text	{}

    groups		text	{}
    questions		text	{}
    choices		text	{}

    target		text	{}
}

Operation Session::_create_ {} {
    variable Default
    
    foreach _var_ [ array names Default ] {
	set ${_var_} $Default(${_var_})
    }
}

## Record indexes of array in this session
Operation Session::record {} {
    variable Conf
    variable ::data::Attributes
    variable ::data::Class

    foreach  { _var_ -  - }	$Attributes($Class(${_Self_})) {

	if [ info exists Conf(${_var_}) ] {
	    set ${_var_} $Conf(${_var_}) 
	}
    }
    
    data::record ${_Self_}
}

## recover to given array the content of this session
Operation Session::recover {} {
    variable Conf
    variable ::data::Attributes
    variable ::data::Class

    foreach  { _var_ - - }	$Attributes($Class(${_Self_})) {

	if [ info exists ${_var_} ] {
	    set Conf(${_var_}) [ set ${_var_} ]
	} else {
	    variable Default
	    
	    if [ info exists Default(${_var_}) ] {
		set Conf(${_var_}) $Default(${_var_})
	    } else {
		set Conf(${_var_}) ""
	    }
	}
    }

}


##------------------- Static methods ------------------------------


## Create a new (folder) session with the appropriate pathname
proc Session::new {} {
    variable Conf
    global env

    assign_new_name

    file::lock $Conf(session)
    data::new $Conf(session) Session

    # recovering defaults (does it make sense?)
    variable Default
    variable ::data::Attributes

    foreach  { _var_ -  - }	$Attributes(Session) {
	if { ! [ info exists Conf($_var_) ] } {
	    if [ info exists  Default(${_var_}) ] {
		set Conf($_var_) $Default(${_var_})
	    } else {
		set Conf($_var_) ""
	    }
	}
    }

    if { 
	! ( 
	   [ info exists env(REQUEST_URI) ] &&
	   [ regexp {/(\d+)(\?.*)?$} $env(REQUEST_URI) - Conf(controller) ] 
	   ) 
    } {
	error "Could not set session hash"
	#set Conf(controller) [ file tail [ info script ] ]
    }
}

## Assign a folder path-name to this session
proc Session::assign_new_name {} {
    variable Conf

    while 1 {
	# clicks instead of seconds since bots requests are too frequent
	set Conf(session) [ format "data/configs/sessions/%s_%s_%s"	\
				[ clock clicks ]			\
				$Conf(user) $Conf(profile) ]

	if [ file readable $Conf(session) ] {
	    # session name exists, wait ranfon time to avoid race
	    after [ expr int(rand()*10000) ]
	} else break
    }    
}

## Open existing session 
proc Session::open {} {
    variable Conf

    file::lock $Conf(session)

    if [ file readable $Conf(session) ] {

	data::open $Conf(session)
	$Conf(session) recover

	return 1

    } else {
	return 0
    }
}

## Close session, generally after processing request.
## Long replies may close the session prematurely
proc Session::close {{process_terminated 1}} {
    variable Conf 
    variable Closed


    if $process_terminated {
	# process pending messages showing them in an alert box
	if { [ info exists Conf(messages) ] && $Conf(messages) != {} } {
	    layout::alert [ join $Conf(messages) \n\n ]
	    set Conf(messages) ""
	}
    }

    if $Closed {
	# this session was already closed: do nothing
    } else {
	# record this session 
	if { $Conf(session) != "" && [ file writable $Conf(session) ] } { 
	    data::open $Conf(session)
	    $Conf(session) record
	} 
	
	file::unlock $Conf(session)    
	
	# cleanup sessions removing those closed by timeout 
	data::open data/configs/sessions
	data/configs/sessions cleanup

	set Closed 1
    }

}

## Create session for this user based on authentication data
## or recover a session based on session ID and authorization.
## No session is created if user is unauthenticated (during login)
proc Session::init {session authorization contest user password command} {
    variable Conf

    set Conf(session) $session
    set Conf(user)    {}
    set Conf(profile) guest
    set Conf(message) ""
    set Conf(command) $command

    if { $user != "" } {	    
	init_after_authentication $contest $user $password

    } else {
	init_current_session $session $authorization $contest $command
    }

    # if a new session was created during initialization then remove the old
    if { $session != $Conf(session) } {
	file delete -force -- $session
    }   
}


## Initialie session by creating a new one with given authentication data
proc Session::init_after_authentication {contest user password} {
    variable Conf

    preserve_configs


    # if { [ info exists Conf(user) ] && [ info exists Conf(profile) ] } {}

    if { [ check_autentication $contest $user $password  ] } {
	::Session::new 	
	restore_configs
    } else {
	if { $Conf(message) == "" } {
	    set Conf(message) "Invalid authentication"

	    set Conf(controller) {}
	    set Conf(style) {base}
	}
    }
}

## Save changeable configurations in temporary array
proc Session::preserve_configs {} {
    variable Conf
    variable ChangeableConf
    variable Preserve

    if [ ::Session::open ] {
	foreach _var_ $ChangeableConf {
	    set Preserve($_var_) $Conf($_var_)
	}
    }
}

## DEPRECATED ???
## Save all all (but session) configs in temporary array
proc Session::preserve_current_configs {} {
    variable Conf
    variable Preserve

    set configs [ array names Conf ]
    set pos     [ lsearch $configs session ]
    set configs [ lreplace $configs $pos $pos ]

    foreach _var_ $configs {
	set Preserve($_var_) $Conf($_var_)
    }
}



# Restore configurations from teporary array
proc Session::restore_configs {} {
    variable Conf
    variable Preserve

    foreach _var_ [ array names Preserve ] {
	set Conf($_var_) $Preserve($_var_)
    }	
}

## Initialize current session (if exists), rechecking authentication
proc Session::init_current_session {session authorization contest command} {
    variable Conf

    if { [ set Conf(session) $session ] == {} } {
	
	set Conf(user) 		guest
	set Conf(profile)	guest
	if { ! [ string equal $command login ] } {
	    set Conf(message)  \
		"Mooshak requires cookies for authentication"
	} 
	::Session::new

    } else {

	if { [ ::Session::open ] } {

	    if { [ string equal $Conf(authorization) $authorization ] } {
		if { 
		    $contest != "" && 
		    ! [ string equal $Conf(contest) $contest ]	
		} {	
		    set Conf(contest) $contest
		    recheck_authenticated 
		}
		
		set Conf(message) ""
	    } else {
		set Conf(message) "Trying to break in?"
		execute::record_error "Trying to break in?"
		set Conf(profile) guest
		recheck_authenticated
	    }
	} else {
	    # session no longer available (probably expired)
	    if { [ duplicated_cookies ] } {
		append Conf(message) "Browser acceded to Mooshak version < 1.3"
		append Conf(message) "<br><blink>Please restart you browser</blink>"
	    } else {
		append Conf(message) "Session expired"
		append Conf(message) \
		    "<br>(you may need to restart your browser)"
	    }

	    set Conf(session) {}		   
	    set Conf(user) 	guest
	    set Conf(profile)	guest
	    ::Session::new
	}
    }
}


## Checks duplicate cookies with same name
## If browser acceded a Mooshak version < 1.3 then it will send both
## cookies with path == / and full path (ex: /~mooshak/cgi-bin/execute/1234)
proc Session::duplicated_cookies {} {
    global env
    
    return [ expr							\
		 [ info exists env(HTTP_COOKIE) ] &&			\
		 [ regsub -all mooshak:session $env(HTTP_COOKIE) {} - ] > 1 ]
}

## Process state for this package before requests 
## in time to include it in cookie headers.
proc Session::_state_ {} {
    variable Conf
    
    switch $Conf(command) {
	logout {
	    file delete -force -- $Conf(session)
	    file::unlock $Conf(session)

	    preserve_configs

	    set Conf(user) 	guest
	    set Conf(profile)	guest
	    ::Session::new

	    restore_configs

	}
	clone {
	    _state_clone_
	}
    }
}


## Create a clone folder from referring session folder 
## but with a new name and the current controller.
## This procedure is invoked BEFORE handling cookies
proc Session::_state_clone_ {} {
    variable Conf
    global env

    set clone_controller $Conf(controller)
    set previous_session $Conf(session)

    if {
	[ info exists env(HTTP_REFERER) ]  &&
	[ regexp {execute/(\d+)} $env(HTTP_REFERER) - controller]  &&
	[ set browser [ cgi::cookie mooshak:browser "" ] ] != "" 
    } {

	foreach session [ glob -nocomplain data/configs/sessions/* ] {
	    ::Session::close 0
	    set Conf(session) $session
	    ::Session::open 
	    
	    if { 
		[ string equal $Conf(controller) $controller ]	&&
		[ string equal $Conf(browser)    $browser    ] 
	    } {

		::Session::close 0

		assign_new_name ;# give new name to current Conf
		set Conf(controller) $clone_controller
		
		file::lock $Conf(session)
		data::new $Conf(session) Session
		$Conf(session) record
		file::unlock $Conf(session)    	


		file delete -force -- $previous_session

		break
	    }
	}
    }	   	    
}



## Check if user profile grants authorization to execute requested command
proc Session::authorized {user} {
    variable Conf

    set auth	0
    set profile	data/configs/profiles/$Conf(profile)
    set sessions data/configs/sessions

    data::open $sessions

    if { $Conf(profile) == "" } {
    } elseif { ! [ file readable $profile ] } {
	set Conf(message) "Invalid profile: $Conf(profile)"
    } elseif { 
	      $user != "" && [ string equal $Conf(profile) "team" ] && 
	      [ $sessions has_enough_sessions $user ] } { 
	set Conf(message) "User '$user' has enough open sessions "
	append Conf(message) "in this contest"

	## invalidate this session
	file delete -force -- $Conf(session)
    } else {	
	set pd [ data::open $profile ]
	set auth [expr [lsearch [set ${pd}::Authorized] $Conf(command)] > -1]

	if { $auth || $user == "" } { 
	    # use message from authentication
	    # set Conf(message) ""

	} else {
	    set Conf(message) "Unauthorized access"
	}

    }

    return $auth
}


## Generic login, redirects to window based on profile
proc Session::login {} {
    variable Conf

    switch $Conf(profile) {
	admin - team - exam {
	    set command  ::$Conf(profile)::$Conf(profile)
	} 
	default {
	    set command ::common::$Conf(profile)
	}
    }

    execute::header $Conf(profile)
    $command
}

## Calling login for a second time
proc Session::relogin {} { login }


## Clone current session
proc Session::clone {} { login }

## Logout from profile
proc Session::logout {} {
    variable Conf

    layout::alert "logging out"
    layout::window_open $Conf(controller)?login _top
}

## Present an application authentication dialog (not the HTTP dialog)
## to be filled in with username and password
proc Session::authenticate {command arguments} {
    variable Conf
    global VERSION

    data::open data/contests
    
    set active 1	;# only active contests are showed
    set update 1	;# update on contest selection
    set registrable 0	;# include non registrable contests

    set contests [ data/contests selector Conf(contest) $active $update \
		       $registrable ]
    set message [ translate::sentence $Conf(message) ]
    set contest data/contests/$Conf(contest)

    if { $message != "" }  { append message "<br>"  }
    append message [ translate::sentence [ check_browser ] ]

    if {
	$Conf(contest) != ""				&&
	! [ catch { data::open $contest } ]		&&
	[ $contest registrable ]
    } {
	set registrable ""
    } else {
	set registrable " disabled "
    }

    set menu_bar [ menu::config_bar ]


    translate::reload	;# Dictionary may have been changed
    translate::labels Mooshak_authentication Contest User Password 

    template::load
    template::write

}

## Reuturns message after checking browser (USER_AGENT)
proc Session::check_browser {} {
    variable KnownBrowsers
    global env

    # foreach var [ array names env ] { puts $var=$env($var)<br>  }

    set valid 0
    if { [ info exists env(HTTP_USER_AGENT) ] } {
	foreach browser $KnownBrowsers {
	    if { [ regexp $browser $env(HTTP_USER_AGENT) ] } {
		set valid 1
		return
	    }
	}
    }

    set message ""
    if $valid {	
	append message [ join $KnownBrowsers ", " ]:$env(HTTP_USER_AGENT)
    } else {
	append message [ translate::sentence "Untested browser" ] " - "
 	append message [ translate::sentence "Mooshak may not work properly" ]
	append message "<br>"
	append message [ translate::sentence "Tested browser include"]:\ 
	append message [ join $KnownBrowsers ", " ]
    }

	return $message
}

## Changing configs from authentication form
proc Session::config {item value} {
    variable Conf
    variable ChangeableConf

    if { [ lsearch $ChangeableConf $item ] > -1 } {
	set Conf($item) $value
    } else {
	set Conf(message) "Trying to change invalid config"
    }

    Session::authenticate "login" ""
}


## Checks request authentication
proc Session::check_autentication {contest user password} {
    variable Conf

    reset_authentication

    foreach path [ authentication_paths $user $contest ] { 
	if { [ set path [glob -nocomplain $path] ] == "" } continue
	if { [ llength $path ] > 1 } {
	    set Conf(message)  [ format "Duplicate login: %s" $user ]
	    return 0
	}
	set user_data  [ data::open $path ] 

	set authenticated 0
	if { [ set ldap [ ldap_authenticator $path ] ] != {} } {
	    # ldap authetication
	    data::open $ldap
	    if { [ set hash [ $ldap authenticate $user $password ] ] != {} } {
		set authenticated 1
	    }
	} else {
	    # basic authentication
	    set hash [ set ${user_data}::Password ] 
	    if [ string equal [ check_password $hash $password ] correct ] {
		set authenticated 1
	    }
	}

	if $authenticated {
	    set Conf(profile) 		[ set ${user_data}::Profile ]
	    set Conf(user) 		$user
	    set Conf(authorization) 	[ crypt $hash:Mooshak ]
	    set Conf(contest) 		$contest
	    set Conf(message) 		""

	    return 1
	} 
    }
    return 0
}

## Returns list of authertication paths 
proc Session::authentication_paths {user contest} {
    ## remove any character used in global expansion


    set paths {}
    if { [ regexp {[\*\?]} $user  ] } {   
	## ignore users with glob expansion wildcards
    } else {    
	if { $user != "" } {
	    if { $contest != "" } {
		
		lappend paths data/contests/$contest/users/$user
		lappend paths data/contests/$contest/groups/*/$user
	    } 
	    lappend paths data/configs/users/$user
	}
    }
    return $paths
}

## return path to LDAP persistent object authenticator, if refered in path
## or the empty string otherwise
proc Session::ldap_authenticator {path} {

    if {
	[ regexp groups $path ]						&&
	[ set group [ data::open [ file dirname $path ] ] ] != {}  	&&
	[ info exists ${group}::Authentication ] 			&&
	[ string equal [ set ${group}::Authentication ] LDAP ]		&&
	[ set ${group}::LDAP ] != {}
    } {
	return data/configs/ldap/[ set ${group}::LDAP ]
    } else {
	return {}
    }      
}

## Recheck authentication when contest changes (user still exists)
proc Session::recheck_authenticated {} {
    variable Conf

    set paths {}
    if { $Conf(user) != "" }  {
	if {  $Conf(contest) != "" } {
	    lappend paths data/contests/$Conf(contest)/users/$Conf(user) 
	    lappend paths data/contests/$Conf(contest)/groups/*/$Conf(user) 
	} 
	lappend paths data/configs/users/$Conf(user)
    }

    set authenticated 0
    foreach path $paths { 	  
	if { [ set path [glob -nocomplain $path] ] == "" } continue	
	if { [ catch { data::open $path } ] } continue
	set authenticated 1
	break
    }   
    if { ! $authenticated } reset_authentication
}

## Reset part of the configuration when session is no longer authenticated
proc Session::reset_authentication {} {
    variable Conf
    
    
    foreach var { user profile authorization } { 
	set Conf($var) "" 
    } 
}


## Encrypt password using crypt()
proc Session::crypt {text} {

    return [ exec bin/pass $text ]
}

## Check plain text password against crypted using crypt()
proc Session::check_password {crypt plain} {

    return [ exec bin/pass $crypt $plain ]
}

## 
proc Session::debug {msg} {
    variable Conf

    set Conf(serial) [ lindex [ split [ file tail $Conf(session) ] _ ] 0 ]
    set fx $Conf(session)/.data.tcl
    if [ file readable $fx ] {
	set data [ file::read_in $fx ]
	regexp "set authorization (\[^\n\]*)" $data - Conf(auth) 

	file stat $fx  stat
	set Conf(mtime) $stat(mtime)
	set Conf(ctime) $stat(ctime)
	set Conf(ino) $stat(ino)
	set Conf(time) [ clock seconds ]
    }

    set str [ format "%-8s " $msg ]
    foreach var { time session command profile user authorization auth mtime ctime ino} {
	if [ info exists Conf($var) ] {
	    set value $Conf($var)
	} else {
	    set value ???
	}	
	append str [ format "%-8s " $value ]
    }
    puts stderr \n$str
}
