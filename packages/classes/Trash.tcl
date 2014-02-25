#
# Mooshak: managing  programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: trash.tcl
# 
## Managing trash 

package provide Trash 1.0

package require data


Attributes Trash {
}

## Empty trash can
Operation Trash::clear ! {

    foreach f [ glob -nocomplain {_$Self_}/* ] {
	file delete -force -- $f
    }
    content::show ${_Self_} 1
}







































































































