#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Check.tcl
# 
## Check list for contest preparetion.

package provide Check 1.0

package require data
package require utils
package require template

namespace eval Check {
}

Attributes Check {

    Name	text	{}
    Definition	fx	{.lst}
    reports	dir	Dir
    resources	dir	Dir
}


Operation Check::check-list ? {
    ${_Self_} show
}

## Shows the check list
Operation Check::show {} {
    variable ::Session::Conf

    set check_list [ file tail ${_Self_} ]

    if { ! [ file exists ${_Self_}/$Definition ] } {
	layout::redirect execute
	layout::alert "Check list definition is missing"
	return
    }

    set fd [ open ${_Self_}/$Definition r ]

    template::load
    template::write head

    set fields {action effect resource}
    foreach field $fields { set $field "" }
    set i 0
    set k 0

    while { [ gets $fd line ] > -1 } {
	if { [ regexp {^\#} $line ] } continue

	regsub -all			\
	    {\[([^>]*)\]} 		\
	    $line \
	    [ format {<code><a href="%s?check+%s+\1">\1</a></code>} \
		  $Conf(controller) $check_list ]	\
	    line

	if { [ set line [ string trim $line ] ] == "" } { 
	    switch $i {
		0 		{ continue			}
		1		{ template::write title		}
		2 		{ template::write line ; incr k	}
	    }
	    set i 0
	} else {
	    set [ lindex $fields $i ] $line
	    incr i
	}

    }

    template::write foot

    catch { close $fd }
}

## Records the checking
Operation Check::record {} {
    template::load
	
    set clist [ file tail ${_Self_} ]

    set date   [ clock format [ clock seconds ] -format %Y/%m/%d ]
    set time   [ clock format [ clock seconds ] -format %H:%M    ]
    set report [ clock format [ clock seconds ] -format %Y-%m-%d_%H:%M ]
    set i 0
    
    set fx ${_Self_}/reports/$report.html
    set template::Channel [ open $fx w ]
    template::write head
    foreach s [ array names cgi::Field t* ] {
	if { $cgi::Field($s) == "" } continue
	if { [	regexp {^t(.*)$} $s - n ] } {
	    set error $cgi::Field($s)
	    template::write lin
	    incr i
	}
    }

    template::write foot
    close $template::Channel

    set fd [ open $fx r ]
    while { [ gets $fd line ] > -1 } {
	puts $line\n
    }
    catch { close $fd } 

    if { $i == 0 } {
	file attributes $fx -permissions g-r
    } else {
	file attributes $fx -permissions g+r
    }
}
