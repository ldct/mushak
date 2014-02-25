#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Network.tcl
# 
## Network of Mooshak servers
## This package includes operation for testing the connectivity in the 
## network, both localy (the nodes connected with this one) and globally
## the graph that is visible from this node.
##
## TODO: Networks should be defined per contest


package provide Network 1.0

package require data
package require ssh
package require Server

namespace eval Network {

    variable Probe ./network	;# network probing command
    variable A			;#  ASCII code of "A"
    scan "A" %c A

}

Attributes Network {

    Server dirs	Server
    
}


# Local connections: servers receiving from and sending to this machine
Operation Network::Connections:local ? {
    

    puts [ format {<h4>%s</h4>} [ translate::sentence "Receiving from" ] ]
    puts <ul>
    foreach lin [ ssh::key_ring ] {
	puts <li>$lin
    }
    puts </ul>

    puts [ format {<h4>%s</h4>} [ translate::sentence "Sending to" ] ]
    puts <ul>
    foreach lin [ Server::replicated ] {
	puts <li>$lin
    }
    puts </ul>

} 

## Global map of conections: graph of all servers reached by this server
Operation Network::Connections:global ? {
    variable Probe

    template::load
    if [ catch { set out [ exec $Probe ] } msg ] {
	layout::alert $msg
    } else {
	set hosts {}

	foreach {h e f t s} [ split $out \n ] {
	    lappend hosts $h
	    if [ regexp ERROR $e ] {
		set from($h) {}	;	set to($h) {}	; set up($h) 0
	    } else {		
		set from($h) $f ;	set to($h) $t 	; set up($h) 1
	    }
	}

	template::write head
	set c -1
	foreach h $hosts { 
	    if $up($h) { set color "white" } else { set color "red" }
	    char_label ref c
	    template::write col
	}
	template::write sep
	set c -1
	foreach o $hosts { 
	    if $up($o) { set color "white" } else { set color "red" }
	    char_label ref c

	    template::write lin_cab

	    foreach d $hosts { 
		set label ""

		if { [ lsearch $to($o) $d ] > -1 } { 
		    append label \[- 
		} else {
		    append label -\]
		}
		if { [ lsearch $from($d) $o ] > -1 } { 
		    append label \]
		} else {
		    append label \[
		}
		# color labels
		switch -- $label {
		    {[-]} { 
			if [ string equal $o $d ] {
			    set color yellow
			} else {
			    set color lightgreen 
			}
		    }
		    {-][} { set color lightgray  }
		    default { set color red }
		}
		template::write cel
	    }
	    template::write lin_rod
	}
	template::write mid
     
	set c -1
	foreach h $hosts {
	    char_label ref c
	    template::write lin2
	}
	template::write foot
    }
}

## Match a letter with a counter
proc Network::char_label {r_ c_} {
    variable A
    upvar $r_ r
    upvar $c_ c

    set r [ format %c [ expr [ incr c ] + $A ] ]
}

## Show current key file 
Operation Network::key:show ? {

    if [ ssh::with_key ] {
	puts <PRE>
	puts [ file::read_in [ ssh::fx_key pub ] ]
	puts </PRE>
    } else {
	layout::alert "Key file missing" [ fx_key pub ] ]
    }

}

## Generate a key file (SSH)
Operation Network::key:generate ! {

    if [ ssh::with_key ] {
	layout::alert "There is a key already"
    } else {
	ssh::create_key
	layout::alert "Key generated" 
    }
    content::show ${_Self_}
}

