#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: exam.tcl
# 
## Processes commands originating in the exam interface
##
## TODO: review FAQ text

package provide exam 1.0

namespace eval exam {

}

## Toplevel team window
proc exam::exam {} {

    set name 		[ contest::team ]
    set id		ID

    if { [  contest::active 0 ] } {

	set contest [ contest::active_path ]
	
	set seg [ data::open $contest ]
	data::open $contest/problems 
	data::open $contest/languages
	data::open $contest/groups

	#foreach {team_name} [ $contest/groups identify [ contest::team ] {} {Name} ] {}
	
	set description	DESCRIPION
    } else {

	set description {<i>nenhum exame definido</i>}
    }


    template::load exam/exam.xml
    template::write

}

