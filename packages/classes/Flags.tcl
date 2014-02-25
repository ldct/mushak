#
# Mooshak: managing programming contests on the web		April 2005
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Flags.tcl
# 
## Group of flags
##

package provide Flags 1.0

namespace eval Flags {

}

Attributes Flags {
    Flag  dirs Flag
}

## mk flags from dir with images
proc Flags::mkflags {
		     {parent	/home/mooshak/data/configs/flags}
		     {dir	/home/mooshak/public_html/icons/flags} 
		     {pattern	*.png}
		     {prefix	f0-}
		 } {

    foreach flag [ glob -nocomplain -dir $dir $pattern ] {
	set name [ file rootname [ file tail $flag ] ]
	regexp ${prefix}(.*) $name - name
	
	set fdir $parent/$name
	
	set fd [ data::new $fdir Flag ]
	set ${fd}::Image [ file tail $flag ]

	data::record $fdir
	
	
	
    }
}

Operation Flags::exists {flag} {

    foreach dir [ glob -nocomplain ${_Self_}/$flag ] {
	set fg [ data::open $dir ]

	if {
	    [ info exists ${fg}::ISO_code ] && 
	    [ string equal [ set ${fg}::ISO_code ] $flag ] 
	} {
	    return 1
	}
    }

    return 0
}