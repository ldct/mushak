#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: QuizChoice.tcl
# 
## Managing a problem in a problem seta

package provide QuizChoice 1.0

package require data
package require xml

namespace eval QuizChoice {


    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Answer		"A statement answering this question"
	Status		"Logic value of this statment"
    }

}

Attributes QuizChoice {
    Fatal	fatal	{}
    Warning	warning {}        

    Answer	long-text	{}
    Status	menu		{true false}

}


Operation QuizChoice::_update_ {} {

    check::reset Fatal Warning

    check::attribute Fatal Answer
    check::attribute Fatal Status {^true|false$}

    if { [ catch { xml::check_embed_xml $Answer } message ] } {
	check::record Fatal simple $message
    }

    return [ check::requires_propagation $Fatal ]

}

## Generate this choice contribution for the exam sheet
## Returns: { correct incorrect void } according to the student choice
Operation QuizChoice::::sheet {quizQuestion grade} {

    set inode [ file::inode ${_Self_} ]

    set attributes [ list xml:id _$inode ]
    set choice [ doc::element_text quizChoice $Answer $attributes ]
    doc::add_child $quizQuestion $choice
    set status void ;# make sure its initialized

    if $grade {

	set selected [ ::cgi::field _$inode false ]

	doc::add_attribute $choice selected $selected
	
	if [ string equal $Status true ] {
	    doc::add_attribute $choice status right
	} else {
	    doc::add_attribute $choice status wrong
	}
	switch $selected {
	    true	{ 
		switch $Status {
		    true		{	set status  correct	}
		    false - default	{	set status  incorrect	}
		} 
	    }
	    false - default		{	set status  void	}
	}
    } else {    	    
	set status 0
    }

    return $status
}


## Checks vars and sub directories
Operation QuizChoice::check {} {
    
    check::dir_start
    # check::vars Name {Timeout {^\d+$} }
    # check::fxs Description Program
    check::sub_dirs
    check::dir_end
}





