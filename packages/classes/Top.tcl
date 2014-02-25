#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: top.tcl
# 
## Top level folder
##


package provide Top 1.0

namespace eval Top {
    
}

Attributes Top {

    Fatal	fatal	{}				\
    Warning	warning {}				\

    configs	dir	Configs
    contests	dir	Contests
    trash	dir	{}
}


Operation Top::_update_ {} {

    set Fatal ""
    set Warning ""

    if { [ info tclversion ] < 8.6 } {


	set message "Listing cache disabled:"
	append message "tclsh version is inferior to 8.6:"
	check::record Warning var $message [ info tclversion ]
    }

    return 0
}