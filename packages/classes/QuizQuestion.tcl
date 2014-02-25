#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: QuizQuestion.tcl
# 
## Managing a problem in a problem seta

package provide QuizQuestion 1.0

package require data
package require xml

namespace eval QuizQuestion {


    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Ask		"Question description"
	Points		"Points in correct"
    }

}

Attributes QuizQuestion {
    Fatal	fatal	{}
    Warning	warning {}        

    Ask		long-text	{}
    Points	text		{}
    choice	dirs	QuizChoice

}


Operation QuizQuestion::_update_ {} {

    check::reset Fatal Warning

    check::attribute Fatal Ask
    check::attribute Fatal Points {^\d*$} ;# Points can be ommited


    if { [ catch { xml::check_embed_xml $Ask } message ] } {
	check::record Fatal simple $message
    }

    switch [ check::dirs Fatal ${_Self_} ] {
	0 {	    check::record Fatal simple   "No items"	 }
	1 {	    check::record Fatal simple   "Just one item defined" }
	1 {	    check::record Warning simple "Only two items defined" }
	3 - 4 - 5 - 6 {}
	default {    check::record Warning simple "Too many items defined" }
    }

    return [ check::requires_propagation $Fatal ]

}

## Generate this question contribution for the exam sheet
## return points for this question
Operation QuizQuestion::sheet {quizGroup grade} {
    variable ::Session::Conf

    set inode [ file::inode ${_Self_} ]

    doc::add_child $quizGroup [ set quizQuestion [doc::element quizQuestion] ]
    doc::add_attribute $quizQuestion xml:id _$inode
    doc::add_child $quizQuestion [ doc::element_text ask $Ask ]
    
    if $grade {
	set choices [ lindex $Conf(choices) 0 ]
	set Conf(choices) [ lrange $Conf(choices) 1 end ]
	lappend Conf(choices) $choices ;# rebuild state for debugging
	if [ regexp {^[0-9]+} $Points ] { 
	    set right_points $Points 
	} else { 
	    set right_points 1 
	    
	}
	set wrong_points [ expr -$right_points.0 /\
			       [ expr [ llength $choices]  - 1] ]
    } else {
	set choices [ ::etc::shuffle \
			  [ data::descendents ${_Self_} QuizChoice ] ] 
	lappend Conf(choices) $choices
	set right_points 0
	set wrong_points 0
    }


    set value 0
    foreach choice $choices {
	data::open $choice

	switch [ $choice sheet $quizQuestion $grade ] {
	    correct	{ set value [ expr $value + $right_points ]	}
	    incorrect	{ set value [ expr $value + $wrong_points ]	}
	    default	{						}
	}
    }
    doc::add_attribute $quizQuestion value $value
    return $value
}


## Checks vars and sub directories
Operation QuizQuestion::check {} {
    
    check::dir_start
    # check::vars Name {Timeout {^\d+$} }
    # check::fxs Description Program
    check::sub_dirs
    check::dir_end
}





