#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Balloon.tcl
# 
## Ballon given to team that solved a problem

package provide Balloon 1.0

namespace eval Balloon {
    variable States {
	"undelivered"
	"delivered"
    }

}

#-----------------------------------------------------------------------------
#     Class definition


Attributes Balloon "

	Date		date		{}		
	Time		text		{}
	Delay		text		{}
	Problem		ref		{../../problems}
	Team		ref		{../../groups/*}
	Submission	ref		{../../submissions/*}
	State		menu		[ list $Balloon::States ]
"

## New ballon ?
Operation Balloon::new {} {
    variable States

    return [ string equal $State [ lindex $States 0 ] ]
}


## Fills a ballon for current submission
proc Balloon::fills {contest problem team} {
    variable States

    data::open $contest

    set dir	 [ contest::transaction balloons $problem $team ]
    set duration [ $contest passed ]
    data::new $dir Balloon
    $dir fills-in $duration $problem $team

    data::record $dir
}

## Fills in with attributes of last submission 
Operation Balloon::fills-in {duration problem team} {
    variable States

    set Date 		[ clock seconds ]
    set Time		$duration 
    set Problem		$problem
    set Team		$team
    set State		[ lindex $States 0 ]
    set Delay		""
}



## Deliver a ballon to a team
Operation Balloon::deliver {{n ?}} {
    variable States
    variable ::Session::Conf
    
    set contest	[ file::canonical_pathname ${_Self_}/../.. ]
    set balloon	[ file tail ${_Self_} ]

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

    
    # set State [ lindex $States end ] ;# let the runners change the state
    foreach st $States {

	if [ string equal $State $st ] { 
	    set check  "checked" 
	} { 
	    set check "" 
	}
	append state [ format { <input 					\
				    type="radio"			\
				    name="State" 			\
				    onClick="this.form.submit();"	\
				    value="%s"%s> } $st $check]
	append state [ translate::sentence $st ]
    }

    set listing $Conf(type)

    set prob 		[ data::open $contest/problems/$Problem ]
    set problem_name	[ set ${prob}::Name ]
    set color		[ set ${prob}::Color ]

    data::open $contest/groups
    foreach {team location} \
	[ $contest/groups identify $Team {} {Name Location} ] {}
    if { $location == {} } {
	set location [ translate::sentence "unknown" ]
    }

    
    set imp ${_Self_}
    set Program ""
    template::load
    template::write

    # if state changes then patch cache (to avoid invalidation)
    if { ! [ string equal $State $previous_state ]  } {    
	data::open $contest
	$contest patch_cache [ file tail ${_Self_} ] $State Balloon
    }

    if $record { data::record ${_Self_} }

}

## Change balloon after delivered
Operation Balloon::delivered {} {

    set State 		[ cgi::field State ]
    set Delay		[ expr [ clock seconds ] - $Date ]

}

## Show balloon
Operation Balloon::show {} {

    template::load answer.html
    template::write 
}


## Show a line in ballons listing
Operation Balloon::listing_line {n m profile} {
    variable States

    set sub [ file tail ${_Self_} ]
    set contest	  [ file::canonical_pathname ${_Self_}/../.. ]
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
    set problem_name [ set ${prob}::Name ]
    set problem_color [ set ${prob}::Color ]

    if [ string equal $profile team ] {
	template::write bal:lin
    } else {
	template::write bal:root
    }

}

