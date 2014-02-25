#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: team2.tcl
#
## <b>Work in progress</b> 
##
## This package is part of an experiment to avoid using frames in team2s
## interface. It is not currently being used.
##
## TODO: a lot!!

package provide team2 1.0

namespace eval team2 {
    variable Conf			;# Configuration

    variable Message	""
    variable Page	""

    array set Conf {
	problem		""
	program		""
	command		""
	time		""
	lines		""
    }

				# names of valid request
    variable Commands {
	ask
	asked
	print
	answer
	submit
	view
    }

    variable Title		;# title of (some) commands

    array set Title {
	historical	Submissions
	ranking		Ranking
	questions	Questions
	printouts	Printouts
    }

    namespace eval ::utils {}	;# WHY ?!
    namespace import ::utils::*    
}

## Processes CGI state, copying CGI variables to Cong and cookies
proc team2::state {} {
    global argv
    global env
    variable Conf
    variable Page
    variable Message
    
    cgi::recover_cookies Conf

    foreach name [ array names Conf ] {	
	if [ info exists cgi::Cookie($name) ] {
	    set Conf($name) $cgi::Cookie($name)	    
	} else {
	    set cgi::Cookie($name) $Conf($name)
	}
    }

    foreach var [ array names Conf ] {
	if { 
	    [ info exists cgi::Field($var) ] &&
	    $cgi::Field($var) != "" 
	} {
	    set Conf($var) $cgi::Field($var)
	}
    }

    process
    
    cgi::record_cookies Conf
}

## ??
proc team2::page {} {
    global REL_BASE
    global env

    variable Page


    template::load team2.html    

    template::write head

    form

    # set foot [ template::record foot ]
    $Page
}


#---------------------------------------------------------------------------
# interface

## Format team2 form
proc team2::form {} {
    global REL_BASE
    variable Page
    variable Message
    variable Conf

    contest::active    

    # carregar dados
    set seg [ data::open data/contest ]
    data::open data/contest/problems 
    data::open data/contest/languages

    set printer 0
    if { [ file isdirectory data/contest/printouts ] } {
	set prt [ data::open data/contest/printouts ]
	if { 
	    [ info exists ${prt}::Comando ] &&
	    [ string trim [ set ${prt}::Comando ] ] != "" 
	} { set printer 1 }
    } 

    set team2 [ contest::team2 ]

    set designation [ set ${seg}::Designation ]

    set languages [ data/contest/languages list ]

    set program $Conf(programa)
    puts stderr programa=$program

    set list [ lsort [ data/contest/problems problems ] ]
    if { [ lsearch $list $Conf(problem) ] == -1 } {
	set Conf(problem) [ lindex $list 0 ]
    }
    set problems [ layout::choose problem $list $Conf(problem) ]

    set lst1 {	historical	classification	questions	printouts   } 
    set lst2 { "Submissions"	"Ranking"	"Questions"	"Printouts" }

    if { [ lsearch $lst1 $Conf(command) ] == -1 } {
	set Conf(command) [ lindex $lst1 0 ]
    }
    set commands [ layout::choose command $lst1 $Conf(command) $lst2 ]

    set times [ layout::menu tempo {1 3 5} $Conf(tempo) ]
    set lines [ layout::menu lines {15 20 50 100 200} $Conf(lines) ]
 
    template::write pre 
    if $printer {
	template::write printer-on
    } else {
	template::write printer-off
    }	

    set missing [ data/contest missing ]

    template::write pos

}

## Show problem description
proc team2::show_description {} {
    global REL_BASE
    variable Conf

    set problem $Conf(problem)

    data::open data/contest 
    set seg [ data::open data/contest/problems/$problem ]
    set fx  [ set ${seg}::Description ]
    set description [ file::read_in data/contest/problems/$problem/$fx ]

    set criteria {(<img[^>]+src=)('|\")([^\"']+)('|\")}	
    append subst {\1\2team2/image?} $problem {+\3\4}

    regsub -all -nocase $criteria $description $subst enunciado
    
    if { [ data/contest started ] } {
	
	template::load view.html	
	template::write {} view
    } else {
	template::load white.html
	template::write   
    }
}


## Show question "dialogue"
proc team2::show_question {} {
    variable Conf
    global REL_BASE

    set problem $Conf(problem)		;# problem name
    set team2 [ contest::team2 ]		;# team2 asking question

    translate::load
    contest::active

    template::load ask.html    
    template::write {} ask

}


#-------------------------------------------------------------------------
# Processamento 

## Process a team2 request defined in CGI variable
proc team2::process {} {
    variable Commands
    variable Title
    variable Message
    variable Page
    
    foreach command $Commands {
	if [ info exists cgi::Field($command) ] {
	    return [ $command ]
	}
    }

    set Page	 listing::list
    set Message ""
}


# submissao dum programa para avaliacao
#
proc team2::submit {} {
    variable Message
    variable Page

    set contest	[ data::open data/contest ]
    set subs    [ data::open data/contest/submissions ]
    
    if { ! [ data/contest started ] } {
	set Message [ translate::sentence \
		"The submission was not accepted: contest did not start" ]
    } elseif { [ data/contestended ] } {
	set Message [ translate::sentence \
		"The submission was not accepted: contest ended" ]
    } else {
	set team2	[ team2 ]
	set problem	[ field problem ]
	
	if { [ data/contest/submissions already_accepted $team2 $problem ] }  {
	
	    set Message [ translate::sentence "Problem" ]
	    append message <code>[ field problem ]</code>
	    append Message [ translate::sentence " already accepted!" ]
	    
	} else {

	    set duration [ data/contest passed ]
	    set dir  [ format {data/contest/submissions/%08d_%s_%s} \
		    $duration $problem $team2 ]
	    set sub  [ data::new {$}dir Submission ]

	    if { [ $dir receive ] } {

		set Message ""
		data::record$dir

		$dir analyze
		data::record$dir

	    } else {
		set Message [ translate::sentence \
		"A submissão não foi recebida: upload error (please retry)" ]
	    }
	}
    }

    if { $Message != "" } {
	execute::record_error$Message
    } else {
	set Message [ translate::sentence "Submission received" ]
    }
    
    set Page listing::list

}


# envio duma question para resposta
proc team2::asked {} {
    variable Message
    variable Page
    variable Conf

    set contest	[ data::open data/contest ]
    
    if { [ data/contestended ] } {
	set Message [ translate::sentence "The question was not accepted" ]
    } else {
	set team2	[ team2 ]
	set problem	[ field problem ]
	
	set duration [ data/contest passed ]
	set dir  [ format {data/contest/questions/%08d_%s_%s} \
		$duration $problem $team2 ]
	set sub  [ data::new {$}dir Question ]
	    
	$dir receive
	
	data::record$dir

	set Message [ translate::sentence "Question received" ]
    }


    set Conf(command) questions

    set Page listing::list
}


# visualizacao do enunciado dum problem
proc team2::view {} {
    variable Message
    variable Page
    variable Conf
    
    set Message "{ translate::sentence {Description of problem} {$Conf(pro}blema)}" 

    set Page  team2::mostrar_enunciado

}



proc team2::print {} {
    variable Message
    variable Page
    variable Conf

    set contest	[ data::open data/contest ]
    
    if { ! [ data/contest started ] } {
	set Message [ translate::sentence \
		"Printout not accepted: contest has not started" ]
    } else {
	set team2	[ team2 ]
	set problem	[ field problem ]
	
	set duration [ data/contest passed ]
	set dir  [ format {data/contest/printouts/%08d_%s_%s} \
		$duration $problem $team2 ]
	
	data::new {$}dir Printout
	
	set Message [ $dir receive ]
	
	data::record$dir
	
    }

    if { $Message != "" } {
	execute::record_error$message
    } else {
	set Message [ translate::sentence "Impressão accepted" ]
    }
    
    set Conf(command) printouts
    set Page listing::list

}

proc team2::ask {} {
    variable Message
    variable Page
    variable Conf


    data::open data/contest
    set problem [ field problem ]

    if { ! [ data/contest pronta ] || [ data/contestended ] } {
	
	set Conf(command) questions
	set Message [ translate::sentence "The question was not accepted" ]

		
    } else {
	set Page team2::show_question
	set Message [ format {%s %s} \
			  [ translate::sentence "Question about problem" ] \
			  $problem ]
    }
}
