#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Server.tcl
# 
## Server in a mooshak network
##

package provide Server 1.0

package require data
package require ssh
package require http

namespace eval Server {
    
    if { ! [ info exists DIR_BASE ] } { set DIR_BASE . } ;# for pkgIndex

    variable Period 	{* * * * *}		;# replication periodicity 
    variable Replicate	./replicate		;# replication program
    variable Pub_key_cgi cgi-bin/public-key	;# cgi returning public key

    variable CRONTAB	/usr/bin/crontab	;# crontab command
    variable HOST	/usr/bin/host		;# host command
}

Attributes Server {

    User 	text	""
    Address	text	""
    URL		text	""
    Public_key		fx	""
    Send	menu	{yes no}
    Receive	menu	{yes no}
    
}

## Tests replication
Operation Server::test ! {
    variable Replicate 

    if { [ catch { set out [ exec  $Replicate $Address $User ] } msg ] } {
	layout::alert "replication error" $msg "$Replicate $User@$Address"
    } else {
	layout::alert "replicating" $out $User@$Address
    }
    content::show $_Self_
}

## If directory is goind to be removed switch off sending and receiving
Operation Server::_destroy_ {} {
    set Send no
    set Receive no    

    ${_Self_} _update_
}

## Updates crontab and ssh when data is changed
Operation Server::_update_ {} {
    variable Replicate
    variable Period
    variable HOST

    if { [ string equal $Address localhost ] } {
	layout::alert "Avoid using localhost as host address"
    }
    

    if { 
	[ catch { set host_output [ exec $HOST $Address ] } ] ||
	[ regexp "Host $Address not found" $host_output ] } {
	layout::alert "Host not found"  $Address
    }

    set tab [ read_crontab ]

    # update if sending
    if [ string equal $Send yes ] {
	if { ! [ regexp [ format {(?n) %s %s$} $Address $User ] $tab ] } {
	    append tab [ format {%s %s %s %s%s} \
			     $Period $Replicate $Address $User \n ]
	    write_crontab $tab
	}
    }

    # update if not sending    
    if [ string equal $Send no ] {
	regsub [format {(?n)^[ ~/\*\.a-zA-Z0-9]* %s %s$%s} $Address  $User \n] $tab {} tab
	write_crontab $tab
    }
    
    # get public key
    set authorized  [ ssh::read_authorized ]
    if { [ file readable ${_Self_}/$Public_key ] } {
	set public_key [ file::read_in ${_Self_}/$Public_key ]
    } else {
	set public_key {}
    }

    # update authorized if not receiving
    if [ string equal $Receive no ] {
	if { $public_key != "" && [ ssh::unauthorized authorized $public_key ] } {
	    ssh::write_authorized authorized
	}
    }

    # update authorized if receiving
    if [ string equal $Receive yes ] {
	if { $public_key == {} } {
	    if [ catch { ${_Self_} ask_key } msg ] {
		layout::alert $msg
		return
	    } else {
		set public_key [ file::read_in ${_Self_}/$Public_key ]
	    }
	}
	if [ ssh::invalid_key $public_key ] {
	    layout::alert "invalid public key"
	} elseif { ! [ ssh::authorized authorized $public_key  ] } {	    
	    ssh::authorize  authorized $public_key
	    ssh::write_authorized authorized
	}
    }    

    return 0
}

## Ask public key to another Mooshak server
Operation Server::ask_key {} {
    variable Pub_key_cgi
        
    # creates URL from data
    if { [ set url [ string trim $URL ] ] == "" } {
	set url http://$Address/~$User/$Pub_key_cgi
    } else {
	if { ! [ regexp [ format {/%s$} $Pub_key_cgi ] $url ] } {
	    if { ! [ regexp {/$} $url ] } { append url / }
	    append url $Pub_key_cgi
	}
    }

    upvar 0 [ http::geturl $url ] state
    
    if { ! [ info exists Public_key ] || $Public_key == "" } {
	set Public_key public_key
	data::record${_Self_}
    }
    
    set fd [ open ${_Self_}/$Public_key w ]
    puts -nonewline $fd $state(body)
    close_and_notify $fd
}

## Returns the content of crontab
proc Server::read_crontab {{notify 1}} {
    variable CRONTAB

    set tab ""
    catch {

	set fd [ open "| $CRONTAB -l" r ]
	while { [ gets $fd line ] > -1 } {
	    if [ regexp {^\#} $line ] continue 
	    append tab $line\n
	}
	close_and_notify $fd $notify
    }
    return $tab
}

## Updates controntab using crontab command
proc Server::write_crontab {tab} {
    variable CRONTAB

    set fd [ open "| $CRONTAB -" w ]
    puts -nonewline $fd $tab
    close_and_notify $fd
}

## Returns list of replicated servers
proc Server::replicated {} {
    variable Replicate 

    set l {}
    foreach lin [ split [ read_crontab ] \n ] {
	if [regexp [format {%s ([^ ]+) ([^ ]+)$} $Replicate] $lin - host user] {
	    lappend l $user@$host
	}
    }

    return [ etc::unique $l ]
}

## Close file/pipe and notify user of possible errors (if relevant)
proc Server::close_and_notify {fd {notify 1}} {

    if { [ catch { close $fd } msg ] } {
	if $notify {
	    layout::alert $msg
	}
    }
}