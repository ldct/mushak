#
# Mooshak: managing programming contests on the web		April 2005
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Flag.tcl
# 
## Flag
##

package provide Flag 1.0

namespace eval Flag {
    array set Tip {
	Image "Flag in PNG format, .png extension and same name as code"
    }

    array set Help {
	Image {
	    Image file names must have the same rootname as the 
	    folder name and ISO code.
	    
	    The file format must be PNG and its extension ".png"
	}
    }
}

Attributes Flag {
    Name	text	{}
    ISO_code	text	{}
    Image	fx	{}
}

