
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Languages.tcl
# 
## Set of languages in with problems can be solved
## Includes operations for 
## </ol>
##      <li>execute and compilation limits</li>
## 	<li>searching a language</li>
## </ol>
##
## Programs are execute with a randomly chosen UID (witin a range) 
## to assure that fork limits do not colide 
##

package provide Languages 1.0

package require data

Attributes Languages {

    Fatal	fatal	{}
    Warning	warning {}        

    MaxCompFork	text	{					:      10 }
    MaxExecFork	text	{					:       0 }
    MaxCore	text	{(bytes) <max core file size>		:       0 }
    MaxData	text	{(bytes) <max DATA segment (STL oblige)	: 2097152 }
    MaxOutput	text	{(bytes) <max output size>		:  512000 }
    MaxStack	text	{(bytes) <max process STACK segment>	: 8388608 }
    MaxProg	text	{(bytes) <max program size 		:  102400 }
    RealTimeout text	{(secs)  <real timeout> 		:      60 } 
    CompTimeout text	{(secs)  <compilation timeout> 		:      60 }
    ExecTimeout	text	{(secs)  <execute timeout>		:       5 }
    MinUID	text	{					:   30000 }
    MaxUID	text	{					:   60000 }

    Language	dirs	Language
}

namespace eval Languages {

    variable Default	;# array of default values

    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	MaxCompFork	"Maximum number of forks during compilation"
	MaxExecFork	"Maximum number of forks during execute"
	MaxCore		"Maximum size of core files in bytes" 
	MaxData		"Maximum size of data segment in bytes"
	MaxOutput	"Maximum size of output files in bytes"
	MaxStack	"Maximum size of stack files in bytes"
	MaxProg		"Maximum size of program in bytes"
	RealTimeout	"Clock (real time)  timeout in seconds"
	CompTimeout	"Compilatiom timeout in seconds"
	ExecTimeout	"Execution (cpu) timeout in seconds"
	MinUID		"Lower bound for generated UIDs acting as user nobody"
	MaxUID		"Upper bound for generated UIDs acting as user nobody"
    }


    array set Default {
	MaxCompFork	     10
	MaxExecFork	      0
	MaxCore		      0
	MaxData	       33554432
	MaxOutput	 512000
	MaxStack	8388608
	MaxProg		 102400
	RealTimeout	     60
	CompTimeout	     60
	ExecTimeout	      5
	MinUID		  30000
	MaxUID		  60000
    }

}

Operation Languages::_create_ {} {

    ${_Self_} set_defaults
}

## Check values on update 
Operation Languages::_update_ {} {
    variable Default

    check::reset Fatal Warning

    foreach name [ array names Default ] {
	check::attribute Fatal $name {^[0-9]+$}
    }    

    append Fatal [ ${_Self_} check_uids ]

    switch [ check::dirs Fatal ${_Self_} ] {
	0 {	    check::record Fatal simple "No languages defined"	  }
	1 {	    check::record Warning simple "Just one language defined" }
    }

    return [ check::requires_propagation $Fatal ]
}

## Restores default values in languages attributes
Operation Languages::defaults ! {

    ${_Self_} set_defaults

    content::show ${_Self_}
}

## Restores default values in languages attributes
Operation Languages::set_defaults {} {
    variable Default

    foreach name [ array names Default ] {
	set $name $Default($name)
    }    

    data::record  ${_Self_}
}

## Cheks UIDs range to be used as nobody
Operation Languages::check_uids {} {
    
    set uids {}
    foreach line [ split [ exec getent passwd ] \n ] {
	set uid [ lindex [ split $line : ] 2 ]
	if { $uid >= $MinUID && $uid <= $MaxUID } {
	    lappend uids [ lindex [ split [exec getent passwd $uid] :] 0 ]:$uid
	}
    }

    if { $uids != {} } {
	if { [ llength $uids ] > 5 } {
	    set uids [ lrange $uids 0 5 ] 
	    lappend uids ...
	}
	return [ format {%s [%s,%s]: %s<br>}			   \
		     [translate::sentence  			   \
			  "Users IDs already defined in interval" ]\
		     $MinUID $MaxUID $uids ]	
    }
    return ""
}

## Sets parameters in calling procedure
Operation Languages::params {} {
    variable Default
    
    foreach name [ array names Default ] {
	set param($name) [ set $name ]
    }

    return [ array get param ]
}

## Propagates checks to sub directories
Operation Languages::check {} {

    check::dir_start 0
    switch [ check::sub_dirs ] {
	0	{ check::report_error Fatal "No language defined" 	}
	1	{ check::report_error Warning "Just one language defined" }
	default {}
    }
    check::dir_end 0
}

## Search a language and returns pathname 
Operation Languages::search {program} {

    set extension [ string trimleft [ file extension $program ] . ]
    foreach lp [ glob -type d -nocomplain ${_Self_}/* ] {
	set lang [ data::open $lp ]
	set ext  [ string trimleft [ set ${lang}::Extension ] . ]

	if { [ string compare $ext $extension ] == 0 } {
	    return $lp
	}
    }
    return {}
}


## Returns a list with all the available languages
Operation Languages::all {} {

    set all {}
    foreach lp [ glob -type d -nocomplain ${_Self_}/* ] {
	lappend all $lp
    }
    return $all
}

## Generates a JS data structure with the extension of the avaliable languages
Operation Languages::JS_array {} {

    set languages [ list "Language = new Array();" ]
 
    foreach lp [ glob -type d -nocomplain ${_Self_}/* ] {
	set lang [ data::open $lp ]
	lappend languages [ format {Language["%s"]="%s";} \
			       [ set ${lang}::Extension ] [ file tail $lp ] ]
    }
    return [ join $languages \n ]
}

