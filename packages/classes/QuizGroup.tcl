#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: QuizGroup.tcl
# 
## Managing a problem in a problem seta

package provide QuizGroup 1.0

package require data

namespace eval QuizGroup {


    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Title		"Title of this group"
	Shuffle		"Shuffle questions in this group? (default is yes)"
	Size		"Number of questions extracted from this group"
    }

}

Attributes QuizGroup {
    Fatal	fatal	{}
    Warning	warning {}        

    Title	text	{}
    Shuffle	menu	{yes no}
    Size	text	{}
    
    quizQuestion	dirs	QuizQuestion

}


Operation QuizGroup::_update_ {} {

    check::reset Fatal Warning

    check::attribute Fatal Title
    check::attribute Fatal Size {^\d*$} ;# Size can be ommited


    switch [ set size [ check::dirs Fatal ${_Self_} ] ]  {
	0 {	    check::record Fatal simple   "No questions"	 }
	1 {	    check::record Warning simple "Just one question"	 }
    }

    if { [ regexp {^\d+$} $Size ] && $size < $Size } {
	 check::record Warning simple "Less questions than size"
    }


    return [ check::requires_propagation $Fatal ]

}


## Checks vars and sub directories
Operation QuizGroup::check {} {
    
    check::dir_start
    # check::vars Name {Timeout {^\d+$} }
    # check::fxs Description Program
    check::sub_dirs
    check::dir_end
}

## Return questions for this group:
##   All questions if no size defined; of if testing
##   the number of questions deined by $Size
Operation QuizGroup::get_questions {} {

    set quiz ${_Self_}/.. ;  data::open $quiz
    

    set questions {}
    foreach dir [ glob -type d -nocomplain ${_Self_}/* ] {
	if [ string equal [ ::data::class $dir ] QuizQuestion ] {
	    lappend questions $dir
	}
    }

    if { 
	! [ $quiz isTesting ] &&
	[ info exists Shuffle ] && ! [ string equal $Shuffle no ] 
    } {
	set questions [ ::etc::shuffle $questions ]
    }

    
    if { 
	! [ $quiz isTesting ] &&
	[ info exists Size ] && [ regexp {^\d+$} $Size ] 
    } {
	set questions [ lrange $questions 0 [ expr $Size - 1 ] ]
    }

    return $questions
}

## Generate this group contribution for the exam sheet
## Returns values for this group
Operation QuizGroup::sheet {quiz grade} {
    variable ::Session::Conf

    doc::add_child $quiz [ set quizGroup [ doc::element quizGroup ] ]
    doc::add_attribute $quizGroup title $Title
    doc::add_attribute $quizGroup xml:id _[ file::inode ${_Self_} ] 

    if $grade {
	set questions [ lindex $Conf(questions) 0 ]
	set Conf(questions) [ lrange $Conf(questions) 1 end ]
	lappend Conf(questions) $questions ;# rebuild state for debugging
    } else {
	set questions [ ${_Self_} get_questions ]
	lappend Conf(questions) $questions
    }

    set value 0
    foreach question $questions {	    
	data::open $question

	set value [ expr $value + [ $question sheet $quizGroup $grade ] ]
    }
    doc::add_attribute $quizGroup value $value
    return $value
}
