#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Quiz.tcl
# 
## Managing a problem in a problem seta

package provide Quiz 1.0

package require data

namespace eval Quiz {

    variable XSLTPROC	/usr/bin/xsltproc		;# xslt processor

    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content


    array set Tip {
	Duration	"Duration of quiz for each student - HH:MM"
	Printing	"Print exam sheets?"
	Printer		"Printer queue name"
	Shuffle		"Shuffle groups of questions?"
	Orientation	"Orientation of possible answers"
	Testing		"Testing quiz (show all problems)"
	CentralMessage	"Message shown/printed at the center of quiz header"
	RightMessage	"Message shown/printed at the right of quiz header"
    }

}

Attributes Quiz {
    Fatal	fatal	{}
    Warning	warning {}        

    Duration	text	{}
    Printing	menu	{yes no}
    Printer	text	{}

    Shuffle	menu	{yes no}
    Orientation menu    {vertical horizontal}
    Testing	menu	{yes no}

    quizGroup	dirs	QuizGroup
    images	dir	Images

    CentralMessage	long-text {}
    RightMessage	long-text {}


}


Operation Quiz::_update_ {} {
    variable XSLTPROC

    check::reset Fatal Warning

    check::execute Fatal $XSLTPROC xslt-proc

    switch [ check::dirs Fatal ${_Self_} ]  {
	0 { 
	    # there is always an image directory
	} 
	1 {	    check::record Fatal simple   "No groups"	 	}
	2 {	    check::record Warning simple "Just one group"	}
    }


    check::attribute Fatal Duration {^\d{1,2}:\d{2}$}

    if { [ regexp {^(\d{1,2}):(\d{2})$} $Duration - hours minutes ] } {
	set seconds [ expr (($hours * 60) + $minutes) * 60 ]


	set sessions [ data::open ${_Self_}/../../../configs/sessions ]
	variable ${sessions}::Timeout

	if { $Timeout - 60 < $seconds } {
	    variable ::Session::Conf

	    set minutes [ expr $Timeout / 60 - 1] 
	    set hours   [ expr $minutes / 60 ]
	    set minutes [ expr $minutes % 60 ]

	    set Duration [ format {%d:%02d} $hours $minutes ] 

	    layout::alert \
		[ format \
		      "Duration must less than session timeout (%s seconds)" \
		      $Timeout ]

	    set url $Conf(controller)?data+data/configs/sessions
	    append message "Configure " \
		[ format {<a href="%s" taget="_top">Sessions</a>} $url ] \
		" if you need to increase session time"

	    append Warning $message
	}
    }

    if { $Printer == "" } {
	set Printer [ print::default_printer ]
    }
    
    return [ check::requires_propagation $Fatal ]

}

## Checks vars and sub directories
Operation Quiz::check {} {
    
    check::dir_start
    # check::vars Name {Timeout {^\d+$} }
    # check::fxs Description Program
    check::sub_dirs
    check::dir_end
}


## Generates an XML quiz sheet, both for an empty sheet solving 
## and the filled sheet for correction.
## $grade is a boolean that is true when the student is submitting the quiz
Operation Quiz::sheet {grade} {
    variable ::Session::Conf

    set contest [ contest::active_path ]
    set seg [ data::open $contest ]
    data::open $contest/groups

    foreach {student} \
	[ $contest/groups identify [ contest::team ] {} {Name} ] {}
    set exam [ set ${seg}::Designation ]
    

    set doc [ doc::document \
		  [ doc::xsl-stylesheet "../../styles/quiz.xsl" ] \
		  [ set quiz [ doc::element quiz ] ] ]

    doc::add_child $quiz [ set header [ doc::element header ] ]

    doc::add_child $header [ doc::element_text designation $exam ]
    doc::add_child $header [ doc::element_text centralMessage $CentralMessage ]
    doc::add_child $header [ doc::element_text rightMessage $RightMessage ]
    doc::add_child $header [ doc::element_text duration $Duration ]
    doc::add_child $header [ doc::element_text student $student ]

    if { 
	[ info exists Orientation ] && 
	[ string equal $Orientation "horizontal" ]
    } {
	doc::add_child $header [ doc::element horizontal-answers ]
    }


    if { $grade } {
	set type answered
    } else {
	# generate groups
	set Conf(groups) 	[ ${_Self_} get_groups ]
	set Conf(questions)	{}
	set Conf(choices)	{}

	if { 
	    ! [ ${_Self_} isTesting ] &&
	    [ info exists Shuffle ] && ! [ string equal $Shuffle no ] 
	} {
	    set Conf(groups) [ ::etc::shuffle $Conf(groups) ]
	}

	set type 		empty
    }

    doc::add_child $header [ doc::element_text type $type ]

    set value 0
    foreach group $Conf(groups) {
	data::open $group

	set value [ expr $value + [ $group sheet $quiz $grade ] ]
    }
    doc::add_child $header [ doc::element_text value $value ]

    set xml [ doc::serialize $doc ]

    if $grade {
	${_Self_} submit $xml $value
    }

    return  $xml
}

## Are we still testing this quiz? (Show all questions, for instance)
Operation Quiz::isTesting {} {

    return [ expr [ info exists Testing ] && [ string equal $Testing "yes" ] ]
}


## Print XML file as HTML after applying XST stylesheet
Operation Quiz::submit {xml value} {
    package require Submission

    variable XSLTPROC
    variable ::Submission::ReportFileName

    set team	[ contest::team ]

    # set dir [ contest::transaction submissions {} $team ]
    # This is a hack: all quiz submissions are assigned problem "-"
    # This helps procedures that require submissions with problem ID
    set dir [ contest::transaction submissions "-" $team ]

    set sub  [ data::new $dir Submission ]
    $dir receive_quiz $value
    data::record $dir

    set html_file ${dir}/$ReportFileName
    set xml_file  ${dir}/quiz.xml
 
    if [ regexp {<\?xml-stylesheet\s(.*?)href="(.*?)"\?>} $xml dec - style ] {

	regsub ${dec} $xml {} xml ;# remove xml-stylesheet 
	set fd [ open $xml_file w ] 
	puts $fd $xml
	close $fd

	regsub {\.\./\.\.} $style public_html style
	exec $XSLTPROC --noout		\
	    --stringparam print yes 	\
	    -o $html_file 		\
	    $style $xml_file

	if { [ string equal $Printing yes ] } {	
	    ::print::data_file $html_file $Printer   
	}
    } else {
	error "Cannot find stylesheet declaration"
    }

}

## Return groups in this quiz
Operation Quiz::get_groups {} {

    set groups {}
    foreach dir [ glob -type d -nocomplain ${_Self_}/* ] {
	if [ string equal [ ::data::class $dir ] QuizGroup ] {
	    lappend groups $dir
	}
    }

    return [ lsort -command Quiz::cmp_group_id $groups ]
    
}

## If group ids end in number sort them according to those numbers
proc Quiz::cmp_group_id {a b} {

    if {
	[ regexp {0*(\d+)$} $a - ga ]  &&
	[ regexp {0*(\d+)$} $b - gb ] } {
	return [ expr $ga > $gb ]
    } else {
	return [ string compare $a $b ]
    }
}




## Import form to uploaded LaTeX file
Operation Quiz::import:latex ? {
    global REL_BASE
    
    set dir ${_Self_} 
    template::load
    template::write 
}

## Importing LaTeX file in the mooshakquiz.sty style
Operation Quiz::importing_latex args {
    variable ::Session::Conf
    variable ::file::TMP

    set filename [ cgi::field file "" ]

    if { $filename == "" } {
	layout::alert "No file selected"
	layout::window_close
	return
    }

    set dir ${_Self_} 

    set tex  [ file::read_in $TMP/$filename ]

    set data [ latex::convert $tex ]

    set header [ file::read_in $dir/.data.tcl ]
    file::write_out $dir/Content.xml $data 

    if [ string equal [ file::encoding $dir/Content.xml ] "ISO-8859" ] {
	file::convert_encoding $dir/Content.xml l1 utf-8
	set data [ file::read_in $dir/Content.xml ]
    }
    
    cleanup $dir

    xml::unserialize $dir $data

    file::write_out $dir/.data.tcl $header

    latex::post_process $dir    


    layout::window_open $Conf(controller)?data+$dir select
    layout::window_close
}

## remove just the groups, not the images, and tem files
proc Quiz::cleanup {dir} {


    foreach group [ glob -nocomplain -type d $dir/* ] {

	catch {

	    set type [ source $group/.class.tcl ]

	    if { [ string equal $type QuizGroup ] } {
		file delete -force $group
		
	    }
	}
    }
    file delete -force $dir/Content.xml
}