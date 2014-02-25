#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Printout.tcl
# 
## Printout management

package provide Printout 1.0

package require data
package require utils

namespace eval Printout {

    variable AvailableVars     ;## variables available in printouts

    set AvailableVars { Problem Team Name Location Program AbsoluteTime ContestTime }

    variable States {
	"undelivered"
	"delivered"
    }

    variable Shell	/bin/bash	;# good old bash

}

#-----------------------------------------------------------------------------
#     Class definition


Attributes Printout "

	Date	date		{}		
	Time	text		{}
	Delay	text		{}
	Problem	ref		{../../problems}
	Team	ref		{../../groups/*}
	State	menu		[ list $Printout::States ]
	Program	fx		{}
"

## Create a new printout (?!!)
Operation Printout::new {} {
    variable States

    return [ string equal $State [ lindex $States 0 ] ]
}

Operation Printout::print ! {

    if { [ set msg [ ${_Self_} do_print ] ] == "" } {
	layout::alert "Program reprinted"
    } else {
	layout::alert $msg
    }

    content::show ${_Self_}
}

## Processes a printout requested by a team
Operation Printout::receive {} {
    variable States
    variable ::file::TMP

    set Date 	[ clock seconds ]
    set Time	[ contest::transaction_time ]
    set Problem	[ cgi::field problem ]
    set Team	[ contest::team ]
    set State	[ lindex $States 0 ]
    set Delay	""
    set Program	[ cgi::field program ]

    file rename -force $TMP/$Program ${_Self_}/$Program

    ${_Self_} do_print 
}

## Create a test printout 
Operation Printout::create_test_page {} {
    variable States
    
    proc pick_dir {glob} {
	return [ file tail [ lindex [ glob -nocomplain -type d $glob ] 0 ] ]
    }

    set Date 	[ clock seconds ]
    set Time	[ clock seconds ]
    set Problem	[ pick_dir ${_Self_}/../../problems/* ]
    set Team	[ pick_dir ${_Self_}/../../groups/*/* ]
    set State	[ lindex $States 0 ]
    set Delay	""
    set Program	hello.c

    set fd [ open ${_Self_}/$Program w ]
    # -- Exemple C Program ------
    puts $fd {
# include <stdio.h>
# include <stdlib.h>

main()
{
    printf("hello world \n");
}
   }
    #----------------------------
    close $fd

    ${_Self_} do_print 
}


# Prints this printout
Operation Printout::do_print {} {
    variable AvailableVars

    if { $Program == "" } {
	return "No filename" 
    }

    set prints [ data::open ${_Self_}/.. ]
    if { [ info exists ${prints}::Command ] } {
	set command  [ string trim [ set ${prints}::Command ] ]
    } else {
	set command ""
    }

    if { ! [ file exists ${_Self_}/$Program ] } {
	return "No file found" 
    }

    if { ! [ regexp text [ file::type ${_Self_}/$Program ] ] } {
	return "Not a text file"
    }
    
    set dir [ file::canonical_pathname ${_Self_}/.. ]
    set pts [ data::open $dir ]

    if { ! [ $dir active ] } { return "Printing is not active" }
    set printer [ set ${pts}::Printer ]
    set layout $dir/[ set ${pts}::Template ]
    set config $dir/[ set ${pts}::Config ]
    if { ! [ file exists $layout ] } {	return "Missing printout template"  }
    if { ! [ file exists $config ] } { 	return "Missing CSS config file"    }
    
    # set vars is reserved namespace
    set ContestTime	[ clock format $Time -format {%H:%M} -gmt 1 ]
    set AbsoluteTime	[ clock format $Date -format {%H:%M} -gmt 0 ]

    set contest [ contest::active_path ]
    data::open $contest/groups
    foreach {Name Location} \
	[ $contest/groups identify $Team {} {Name Location} ] {}
    if { $Location == {} } {
	set Location [ translate::sentence "unknown" ]
    }

    namespace eval data [ list set Content 				\
			      [ layout::protect_html 			\
				    [file::read_in ${_Self_}/$Program] ] ]
    foreach var $AvailableVars {	
	namespace eval data [ list set $var [ set $var ] ]
    }

    # eval layout in reserved namespace
    set printout [ namespace eval data \
		       [ list subst -nocommand [ file::read_in $layout ] ] ]


    catch { print::data $printout $printer $config } msg

    return $msg
}

## Form to change this printout state
Operation Printout::deliver {{n ?}} {
    variable States
    variable ::Session::Conf
    
    set contest	 [ file::canonical_pathname ${_Self_}/../.. ]
    set printout [ file tail ${_Self_} ]

    # mark this session as modified now for cache control
    set Conf(modified) [ clock seconds ]
    set previous_state $State
    
    set record 0
    foreach var { State } {
	if { 
	    [ info exists cgi::Field($var) ] && 
	    [ string compare $cgi::Field($var) [ set $var ] ] != 0
	} {
	    set $var $cgi::Field($var)
	    set record 1
	}
    }

    # set State [ lindex $States end ] ;# let the judges change state
    foreach st $States {

	if [ string equal $State $st ] { 
	    set check " checked" 
	} { 
	    set check "" 
	}
	append state [ format { <input 				\
				     type="radio" 			\
				     name="State" 			\
				     onClick="this.form.submit();" 	\
				     value="%s"%s> } $st $check ]
	append state [ translate::sentence $st ]

    }

    set listing $Conf(type)

    set prob [ data::open $contest/problems/$Problem ]
    set problem_name [ set ${prob}::Name ]
    set color    [ set ${prob}::Color ]

    data::open $contest/groups
    foreach {team location} \
	[ $contest/groups identify $Team {} {Name Location} ] {}
    if { $location == {} } {
	set location [ translate::sentence "unknown" ]
    }

    set imp ${_Self_}

    template::load 
    template::write

    # if state changes then patch cache (to avoid invalidation)
    if { ! [ string equal $State $previous_state ]  } {    
	data::open $contest
	$contest patch_cache [ file tail ${_Self_} ] $State Printout
    }

    if $record { data::record ${_Self_} }

}

## Change printout state after delivery
Operation Printout::delivered {} {

    set State 		[ field State ]
    set Delay		[ expr [ clock seconds ] - $Date ]

}

## Show printout and answer
Operation Printout::show {} {

    template::load answer.html
    template::write 
}

## Line from printouts listing relative to this printout
Operation Printout::listing_line {n m profile} {
    variable States

    set contest	  [ file::canonical_pathname ${_Self_}/../.. ]

    set sub [ file tail ${_Self_} ]

    data::open $contest/groups

    layout::toggle_color m color    

    foreach {group_color group_flag group_acronym team_name} \
	[ $contest/groups identify $Team {Color Flag Acronym} {Name} ] {}

    set state [ translate::sentence $State ]
    set hour [ date::format $Time $Date ] 

    if { [ lsearch $States	$State		] == 0 } {
	set state <b>$state</b>
    } else {
	layout::color state gray
    }

    set prob [ data::open $contest/problems/$Problem ]
    set problem_name  [ set ${prob}::Name ]
    set problem_color [ set ${prob}::Color ]

    if [ string equal $profile team ] {
	template::write pri:lin 
    } else {
	template::write pri:root
    }
}
