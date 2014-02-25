#
# Mooshak: managing programming contests on the web		May 2004
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Sessions.tcl
# 
## Set of user sessions 

package provide Sessions 1.0

package require data
package require Session

namespace eval Sessions {

    variable Default_Timeout	3600	;## default timeout, in seconds
     variable Tip

    array set Tip {
	Timeout		"Maximum time in seconds for an idle session"

	Maximum_sessions "Maximum number of simultaneous session per team"
    }
}

Attributes Sessions {

    Timeout 		text	{}
    Maximum_sessions	text	{}
    Session 		dirs	Session
    
}

Operation Sessions::_create_ {} {
    ${_Self_} _update_
}

Operation Sessions::_update_ {} {

    if { ! [ regexp {^[0-9]+$} $Timeout ] } {
	variable Default_Timeout

	set Timeout $Default_Timeout
    }
    return 0
}


## Return number of currently active sessions 
Operation Sessions::count { {suffix ""} } {
    
    return [ llength [ glob -nocomplain -type d ${_Self_}/*$suffix ] ]
}

## Cleanup sessions and remove inactive sessions.
## Sessions modified more than $Timeout seconds ago are deleted.
Operation Sessions::cleanup {} {
    set now [ clock seconds ]

    foreach session [ glob -nocomplain -type d ${_Self_}/* ] {
	if { [ file mtime $session ] + $Timeout < $now } {
	    file delete -force -- $session
	}
    }
}

## Notify users with messge. Messages will be shown in an alert box.
## User name and profile can be used to select message recipients.
## By default messages are delivered to all users with team profile.
## Messages are propagated to remote servers but not re propagated
Operation Sessions::notify {message {user *} {profile team} } {
    global REL_BASE DIR_BASE

    notify_local ${_Self_} $message $user $profile

    foreach rep [ split  [ Server::read_crontab [ set notify 0 ]  ] \n ] {
	if [ regexp {replicate ([\w\.]+) (\w+)$} $rep - host install ] {
	    notify_remote $install $host $message $user $profile
	}
    }
}


#
# Notify with $message all sessions in $dir that match $user and $profile
proc Sessions::notify_local {dir message user profile} {
    variable ::Session::Lock
    global REL_BASE DIR_BASE

    set pattern [ format %s/*_%s_%s $dir $user $profile ]

    foreach session [ glob -nocomplain -type d $pattern ] {

	## USE THIS LOCK  WHEN WRITTING SESSIONS!!!
	file::lock $session
	set sp [ data::open $session ]
	lappend ${sp}::messages [ translate::sentence $message ]
	data::record $session
	file::unlock $session
    }
}

#
# Notify with $message all sessions in $install at $host
#  matching $user and $profile
proc Sessions::notify_remote {install host message user profile} {
    global REL_BASE DIR_BASE
    

    set fd [ open "| ssh $install@$host tclsh" r+ ]

    puts $fd [ format {lappend auto_path packages} ]
    puts $fd [ format {source .config} ]
    puts $fd [ format {package require data}  ]
    puts $fd [ format {package require file}  ]
    puts $fd [ format {package require Sessions}  ]
    puts $fd [ format {file::startup_tmp} ]
    set dir data/configs/sessions
    set command [ format {Sessions::notify_local %s "%s" %s %s} \
		   $dir $message $user $profile ]
    puts stderr command=$command
    puts $fd $command
    flush $fd

    puts $fd [ format {puts stderr "ending remote execution"} ]

    puts $fd [ format {exit} ]
    catch { close $fd } msg
    # puts stderr "MSG: $msg"
}


Operation Sessions::teams ? {

    template::load Sessions/list

    template::write head
    set m 0

    set now [ clock seconds ]
    set count 0
    foreach session [ glob -nocomplain -type d ${_Self_}/* ] {
	   
	set sd [ data::open $session ]

	variable ${sd}::profile
	variable ${sd}::user
	variable ${sd}::contest

	file stat $session stat

	set age   [ clock format [ expr $now - $stat(atime) ] -format "%M:%S" ]
	set idle  [ clock format [ expr $now - $stat(mtime) ] -format "%M:%S" ]

	if { [ string equal $profile team ] } {

	    layout::toggle_color m color
	    template::write line
	    incr count
	}
	 
    }

    template::write foot

}


## cheks if user alread has enough open sessions
Operation Sessions::has_enough_sessions {user} {
    variable ::Session::Conf

    if { 
	[ info exists Maximum_sessions ]  &&
	[ regexp {^\d+$} $Maximum_sessions  ]
    }  {
	if { $Maximum_sessions == 0 } {
	    return 1
	} else {      
	    set count 0	
	    foreach session [ glob -nocomplain -type d ${_Self_}/* ] {
		set sd [ data::open $session ]
		
		if { 
		    [ string equal [set ${sd}::user ] $user ]		  &&
		    [ string equal [set ${sd}::contest ] $Conf(contest) ] &&
		    [ incr count ] >= $Maximum_sessions
		} {
		    return 1
		}
	    }
	}
    }

    return 0
}
