#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Team.tcl
# 
## Team participation in a contest. 
## Team Id is the directory name and cannot have non-alphanumeic chars
## The Name can have all sorts of chars (spaces, operators et)
## Authentication used Id and Password.
## Qualifies is used in public contest to marks those not qualifying.
##
## TODO: improve groups export

package provide Team 1.0

package require data


namespace eval Team {
    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    variable CACHE_FILE .cache ;# file containing cached data

    array set Tip {
	Name	  "Team long name (this is NOT the team ID)"
	Password  "Password for authentication (with team ID: folder name)"
	Email	  "Email address for contact"
	Location  "Location in lab where team is competing"
	Qualifies "Team qualifies for this contest or is in a public contest?"
	Rank	  "Team position in final ranking"
	Start	  "Date / time when team logged in"


	feedbacks "Directory containing feedback given to team / student"
    }
}

Attributes Team {
    Fatal	fatal		{}			
    Warning	warning 	{}

    Name	text		{}
    Password	password	{}
    Email	text		{}
    Location	text		{}
    Qualifies	menu		{yes no}
    Person	dirs		Person
    Start	date		{}
    Rank	status		{}
    Profile	hidden		{}
}

## Check the team (not its members)
Operation Team::check {} {


    check::dir_start
    check::vars Name Password
    check::dir_end
}

## Team NOT qualifies for contest? 
## Useful when merging public and official contest
Operation Team::disqualified {} {
    return [ expr [ string equal $Qualifies no ] ]
}

## Show this team certificate
Operation Team::certificate:show ? {
    puts [ ${_Self_} certificate ]
}

## Print team certificate for this team
Operation Team::certificate:print ! {

    set groups  [ file::canonical_pathname ${_Self_}/../.. ]
    set gps     [ data::open $groups ]
    set printer [ set ${gps}::Printer ]
    set config  ${_Self_}/../../[ set ${gps}::Config ]

    if { $printer == "" } {
	layout::alert "Missing printer name"
    } elseif { ! [ file readable $config ] } {
        layout::alert "Missing CSS config file"        
    } else {
	catch { print::data [ ${_Self_} certificate ] $printer $config } msg
	if { $msg == "" } { set msg "Printed certificate" }	
	layout::alert $msg
    }
    content::show ${_Self_}
}

## Returns a string with the an HTML formated certificate for this team
Operation Team::certificate {} {

    set groups [ file::canonical_pathname ${_Self_}/../.. ]
    set group  [ file::canonical_pathname ${_Self_}/.. ]

    set grs [ data::open $groups ]
    set gr  [ data::open $group  ]

    set Team_template	[ set ${grs}::Team_template ]    

    if { ! [ file exists $groups/$Team_template ] } {
	layout::alert  "Missing team template"
	return {}
    }

    set names {}
    foreach person [ glob -type d -nocomplain ${_Self_}/* ] {
	set sp [ data::open $person ]
	lappend names [set ${sp}::Name ]
    }

    regsub -all _ $Name { } name
    
    set classifier [ classify::classifier ]
    namespace eval data [ list set Group [ set ${gr}::Designation ] ]
    namespace eval data [ list set Team $name ]
    namespace eval data [ list set Names [ join $names <br> ] ]
    namespace eval data [ list set Rank  [ $classifier $Rank F ] ]

    return [ namespace eval data \
		 [ list subst -nocommands \
		       [ file::read_in $groups/$Team_template ] ] ]
	       
}

## Initializes a team
Operation Team::_create_ {} {
    set Name [ file tail ${_Self_} ]
    set Password [ password::generate ]

    data::record ${_Self_}
}


## Update this team after user changes:
##      don't leave this team without password
##	remove strange characters from name
##	update group and password files. (no longer needed) ??
Operation Team::_update_ {} {

    check::reset Fatal Warning

    set Profile team
    # password::update ${_Self_} ../../.. Name Password

    check::attribute Fatal Name
    check::attribute Fatal Password
    check::attribute Warning Email

    switch [ check::dirs Warning ${_Self_} ] {
	0 {	    check::record Warning simple "No persons in this team"  }
	1 {	    check::record Warning simple "Just one person in this team" }
    }    

    return [ check::requires_propagation $Fatal ]
}

## Export this team in text format
Operation Team::export {} {

    puts [ format {%20s} $Name ]
    foreach person [ glob -type d -nocomplain ${_Self_}/* ] {
	data::open $person
	$person export
    }
}

## Generate a password for this team.
Operation Team::password:generate ! {


    set contest [ file::canonical_pathname ${_Self_}/../../.. ]
    set cnt [ data::open $contest ]
    set name 	 [ set ${cnt}::Designation ]

    set groups   [ file::canonical_pathname ${_Self_}/../.. ]
    set grp	 [ data::open $groups ]
    set template $groups/[ set ${grp}::Password_template ]
    set printer	 [ set ${grp}::Printer ]
    set config	 [ set ${grp}::Config ]
    
    print::data [ ${_Self_} password_sheet $name $template ] $printer $config

    layout::alert "Password printed" 
    content::show ${_Self_}
}

## Generate passwords of this team to an archive
Operation Team::password:generate-to-archive ! {

    set contest ${_Self_}/../../..
    set groups	${_Self_}/../..
    set dir	${_Self_}
    set pattern ${_Self_}

    Groups::generate_passwords_to_archive $contest $groups $dir $pattern

    layout::alert "Password generated" 
    content::show ${_Self_}
}

## Returns a string with the an HTML formated password sheet for this team
## given contest name and template
Operation Team::password_sheet {contest template} {
    
    set password [ password::generate ]
    set Password [ Session::crypt $password ]
    data::record ${_Self_}

    set group [ file::canonical_pathname ${_Self_}/.. ]
    set gr [ data::open $group ]


    namespace eval data [ list set Contest $contest ]
    namespace eval data [ list set Team $Name ]
    namespace eval data [ list set Group [ format {[%s] %s}		  \
					       [ set ${gr}::Designation ] \
					       [ set ${gr}::Acronym ] ] ]
    namespace eval data [ list set Login [ file tail ${_Self_} ] ]
    namespace eval data [ list set Password $password ]

    return [ namespace eval data \
		 [ list subst -nocommands [ file::read_in $template ] ] ]
    
}

## Returns time passed from the moment the team logged for the first time  
Operation Team::passed_from_login {now} {
    
    if { [ info exists Start ] && [ regexp {^[0-9]+} $Start ] } {
	return [ expr $now - $Start ]
    } else {
	return $now
    }

}

## Sets login time, used in virtual contests
Operation Team::record_login_time {} {
    
    if { [ info exists Start ] && [ regexp {^\d+$} $Start ] } {
	# Start time was already recorded and its valid
    } else {
	set Start [ clock seconds ]
    }

    data::record ${_Self_}
}

# Menu callback to clean the cache
Operation Team::cache:clean ! {
    ${_Self_} cache_clean

    layout::alert "Chache cleaned" 
    content::show ${_Self_}
}

# Clean cached data (used for fast revaluation of rankings)
Operation Team::cache_clean {} {
    variable CACHE_FILE

    file delete -force ${_Self_}/$CACHE_FILE

}