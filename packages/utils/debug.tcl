#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: debug.tcl
# 
## Debugging utilities

package provide utils 1.0

namespace eval debug {

}

## Profiles command execute times in stdout
proc debug::profile {commands} {

    puts <pre>
    set total 0
    set command ""
    foreach line [ split $commands \n ] {
	# remove comments :-)
	regexp {^([^\#]+)\#} $line - line
	if { [ set line [ string trim $line ] ] == "" } continue 

	append command $line\n

	if [ info complete $command ] {
	    set time [ lindex  [ time [ list uplevel  $command ] ] 0 ]
	    puts -nonewline [ format {%10d %s} $time $command ]
	    incr total $time 
	    set command ""
	}
    }
    puts [ format {<b>Total:</b> %s} $total ]
    puts </pre>

}

proc debug::trace {commands} {
    set k 0
    set command ""
    foreach line [ split $commands \n ] {
	# remove comments :-)
	regexp {^([^\#]+)\#} $line - line
	if { [ set line [ string trim $line ] ] == "" } continue 

	append command $line\n

	if [ info complete $command ] {
	    puts >$command
	    uplevel  $command
	    puts <$command
	    set command ""
	}
    }
}
