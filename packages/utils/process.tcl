#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: process.tcl
# 
## Utilities for dealing with processes

package provide process 1.0

namespace eval process {
    variable Time_ended

    namespace export timeout		;## Waits for the process conclusion
}


## Execute command line in dir
proc process::exec_in_dir {cmd dir} {
    
    set here [ pwd ]
    cd $dir
    if [ catch { eval exec $cmd } msg ] {
	cd $here
	layout::alert $msg
    }
    cd $here
    # return stdout of command
    return $msg
}

## Waits a given time for the conclusion of process associated to a stream
## Safeexec made this procedure redundant
proc process::timeout {fd timeout} {
    variable Time_ended
    
    set Time_ended($fd) 0
    fileevent $fd readable [ list set ::process::Time_ended($fd) 0 ]
    set id [ after $timeout [ list set ::process::Time_ended($fd) 1 ] ]

    vwait ::process::Time_ended($fd)
    if $Time_ended($fd) {
	# catch { close $fd } ;# cannot close or it will keep waiting
	exec bash -c [ list kill -9 [ pid  $fd ] ]
    } else {
	catch { after cancel $id }
    }
    return $Time_ended($fd)
}
