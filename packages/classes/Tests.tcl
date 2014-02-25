#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Tests.tcl
# 
## Class for the set of tests
##
## TODO: Verify test generation from definition

package provide Tests 1.0

package require data
package require tests

Attributes Tests {

    Fatal	fatal	{}
    Warning	warning {}        
    
    Definition	fx	{}
    Test	dirs	Test
}

## Propagates checks for all sub-directories
Operation Tests::check {} {

    check::dir_start
    check::sub_dirs

    set n [ llength [ glob -nocomplain ${_Self_}/* ] ] 

    if { $n == 0 } {
	check::report_error Fatal {No test}
    } elseif { $n == 1 } {
	check::report_error Warning {Just <b>1</b> test}
    } elseif { $n < 4 } {
	check::report_error Warning [ format {Just %d tests} $n ]
    }
    check::dir_end
}


Operation Tests::_update_ {} { 

    check::reset Fatal Warning

    switch [ check::dirs Fatal ${_Self_} ] {
	0 {	    check::record Fatal simple   "No tests defined"	 }
	1 {	    check::record Warning simple "Just one test defined" }
	2 - 3 - 4 { check::record Warning simple "Few tests defined"     }
    }

    return [ check::requires_propagation $Fatal ]
 
}

## Generate tests from definition
Operation Tests::generate-from-definition ! { 

    set fx  ${_Self_}/$Definition

    if { [ catch { 
	tests::generate ${_Self_} [ file::read_in $fx ] 
    } execute::report_error ] } {
	set message "$execute::report_error"
    } else {
	set message "generated new tests"
    }

    layout::alert $message

    set problem [ file::canonical_pathname ${_Self_}/.. ]
    data::open $problem
    $problem test
    
    content::show ${_Self_} 0
}
