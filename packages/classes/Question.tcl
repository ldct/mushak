#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@dcc.fc.up.pt
#
#-----------------------------------------------------------------------------
# file: Question.tcl
# 
## Manages team questions/answers and warnings

package provide Question 1.0

namespace eval Question {
    variable States {
	"unanswered"
	"already answered"
	"without answer"
	"answered"
    }

    variable Trunc	60			;# chars of question in listing

}

#-----------------------------------------------------------------------------
#     Class definition


Attributes Question "

	Date		date		{}		
	Time		text		{}
	Delay		text		{}
	Problem		ref		{../../problems}
	Team		ref		{../../groups/*}
	State		menu		[ list $Question::States ]
	Subject		text		{}
	Question	long-text	{}
	Answer 		long-text	{}
"

## New question
Operation Question::new {} {
    variable States

    return [ string equal $State [ lindex $States 0 ] ]
}

## Processes submition sent by a team
Operation Question::receive {} {
    variable States

    set Date 		[ clock seconds ]
    set Time		[ contest::transaction_time ]
    set Subject		[ layout::strip_tags [ cgi::field subject ] ]
    set Problem		[ cgi::field problem ]
    set Team		[ contest::team ]
    set Classify	""
    set Observations 	""
    set State		[ lindex $States 0 ]
    #set Question	[ layout::strip_tags [ cgi::field question ] ]
    set Question	[ layout::protect_html [ cgi::field question ] ]
    set Delay		""

    set questions [ file::canonical_pathname ${_Self_}/.. ]
    data::open $questions
    if [ $questions forward ] {
	${_Self_} forward contest
    }
}


# Forward this question to { contest team }
Operation Question::forward {{who contest}} {

    set contest_path [ file::canonical_pathname ${_Self_}/../.. ]
    set mail_log [ file::canonical_pathname ${_Self_}/.. ]/mail_log

    foreach lang [ translate::langs ] {
	set frm templates/$lang/Question/send_question.txt
	if [ file readable $frm ] {
	    break
	}
    }

    set ct [ data::open $contest_path ]
    set sender  [ set ${ct}::Designation ]
    set from    [ set ${ct}::Email ]

    switch $who {
	contest	{
	    set recipient $sender
	    set to $from
	}
	team {
	    set team_path [ glob -nocomplain ${_Self_}/../../groups/*/$Team ]
	    set td [ data::open $team_path ]
	    set recipient [ set ${td}::Name  ]
	    set to   [ set ${td}::Email ]
	}
    }

    email::send $from $to $frm $mail_log
}

## Reply to a question sent by a team
Operation Question::answering {{n ?}} {
    variable States    
    variable ::Session::Conf

    template::load 

    set contest	 [ file::canonical_pathname ${_Self_}/../.. ]
    set question [ file tail ${_Self_} ]

    set record 0
    foreach var { State Subject Question Answer } {
	if { [ set value [ cgi::field $var "" ] ] != "" &&
	     ! [ string equal $value  [ set $var ] ]
	 } {
	    set $var $value
	    set record 1
	}
    }

    if $record { 
	data::record ${_Self_}
	if { [ string equal $State [ lindex $States end ] ] } {
	    data::open data/configs/sessions
	    if { $Team == "" } {
		data/configs/sessions notify "The judges modified a warning"
	    } else {
		data/configs/sessions notify "Your question was answered" $Team
	    }
	}

	set questions [ file::canonical_pathname ${_Self_}/.. ]
	data::open $questions
	if [ $questions forward ] {
	    ${_Self_} forward team
	}

    }    

    if [ string equal $State [ lindex $States 0 ] ] {
	set State [ lindex $States end ] 
    }

    set state [ layout::choose State $States $State ]
    set listing $Conf(type)

    if { $Problem == "" } {
	set problem_name *
	set problem_color white	
    } else {
	set prob [ data::open $contest/problems/$Problem ]
	set problem_name  [ set ${prob}::Name ]
	set problem_color [ set ${prob}::Color ]
    }
    
    if { $Team == "" } {
	set team [ translate::sentence Judge ]
	layout::color team red
    } else {
	set team $Team
    }
    

    template::write head
    switch $State {
	"unanswered" - 	"answered"	{     template::write normal }
	"already answered"		{     

	    if { [ set menu [ ${_Self_} similar_questions_menu ] ] == "" } {
		set msg [ translate::sentence "No matching questions" ]\n
		append msg [ translate::sentence \
			 "Are you sure this question was already answered?" ]
		layout::alert $msg
		template::write normal
	    } else {		
		template::write already 

	    }
	}
	"without answer" - default	{     template::write none }

    }
    template::write foot


}


## Returns menu of similar questions (answers to the same problem)
Operation Question::similar_questions_menu {} {
    foreach qdr [ glob -nocomplain -type d [ file dir ${_Self_} ]/* ] {
	
	set que [ data::open $qdr ]
	set f {%-30s | %-40s}
	if {  [ string equal [ set ${que}::State ] "answered" ] &&
	      [ string equal [ set ${que}::Problem ] $Problem ]
	  } {
	    lappend values [ file tail $qdr ]
	    set subject [ set ${que}::Subject ]
	    if { [ string length $subject ] > 20 } {
		set subject [ string range $subject 0 27 ]...
	    }
	    set question [ set ${que}::Question ]
	    if { [ string length $question ] > 20 } {
		set question [ string range $question 0 37 ]...
	    }
	    set text [ format $f $subject $question ]
	    regsub -all { } $text _ text
	    lappend texts  $text
	    data::close $qdr
	}
    }
    if [ info exists values ] {
	return [ layout::menu Answer $values $Answer $texts 5 ]
    } else {
	return {}
    }
}


## Change question after being answered
Operation Question::answered {} {

    set Subject		[ cgi::field Subject ]
    set Question	[ cgi::field Question "" ]
    set State 		[ cgi::field State ]
    set Answer		[ cgi::field Answer ]
    set Delay		[ expr [ clock seconds ] - $Date ]
}


## Change question used as warning
Operation Question::warned {} {
    variable States

    set Date 		[ clock seconds ]
    set Subject		[ cgi::field subject ]
    set Problem		[ cgi::field problem "" ]
    set Team		""
    set State		[ lindex $States end ]
    set Answer		[ cgi::field answer ]
    set Delay		0
    set Time		[ contest::transaction_time ]

    data::open data/configs/sessions
    data/configs/sessions notify "The judges issued a warning"


}

## Show question and answer
Operation Question::answer {} {

    template::load answer.html

    set Question [ layout::protect_html $Question ]
    set Answer   [ layout::protect_html $Answer ]

    template::write 
}


# formats line in question listing
Operation Question::listing_line {n m profile} {
    variable ::Session::Conf
    variable States
    variable Trunc

    set contest	  [ file::canonical_pathname ${_Self_}/../.. ]
    layout::toggle_color m color
    set sub [ file tail ${_Self_} ]
    data::open $contest/groups

    if [ expr $m % 2 ] { set color white } else { set color lightGrey }
    
    foreach {group_color group_flag group_acronym team_name team_qualifies} \
	[ $contest/groups identify $Team {Color Flag Acronym} 		    \
	      {Name Qualifies} ] {}

    regsub -all {[\ \n\t\r]+} $Subject { } subject

    if { [ string length $subject ] > $Trunc } {
	set subject [ string range $subject  0 [ expr $Trunc-3 ]  ]... 
    }

    set hour [ date::format $Time $Date ] 
    set state	[ translate::sentence $State ]
    set link	{<a target ="%s" href="%s?answer+%s">%s</a>}
    
    switch $team_qualifies {
	no		{ set dest {font color="orange"} }
	yes - default	{ set dest N }
    }

    switch $State {
	"answered" {
	    set window [ expr [ string equal $profile team ]?"work":"bottom" ]
	    set state [ format $link $window $Conf(controller) $sub  $state ]
	}
	"already answered" {
	    if { $Answer != "" } {
		set window [ expr [ string equal $profile team ]?"work":"bottom" ]
		set state [ format $link $window $Conf(controller) $Answer $state ]
	    }
	}
    }

    if { [ lsearch $States	$State		] == 0 } {
	set state <b>$state</b>
    } else {
	layout::color state gray
    }

    if { $Problem == "" } {
	set problem_name   [ format {<font size="-1"><i>%s</i></font>} \
				 [ translate::sentence "All" ] ]
	set problem_color black
    } else {
	set prob [ data::open $contest/problems/$Problem ]
	set problem_name	[ set ${prob}::Name ]
	set problem_color	[ set ${prob}::Color ]
    }

    if { $Team == "" } {
	# clarification posted by judges
	if { $Problem == "" } { set Problem &nbsp; }
	if [ regexp {^admin|judge$} $profile ] {
	    template::write que:root_warning
	} else {
	    template::write que:normal_warning
	}
    } elseif [ regexp {^admin|judge$} $profile ] {
	template::write que:root
    } else {
	if [ string equal [ cgi::field problem "" ] $Problem ] {
	    template::write que:lin_enf
	} else {
	    template::write que:lin 
	}
    }

}
