#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Person.tcl
# 
## Person from a team (contestant or coach)

package provide Person 1.0

package require data

Attributes Person {

    Fatal	fatal	{}
    Warning	warning {}

    Name	text	{}
    Role	menu	{Coach	Contestant}
    Sex		menu	{M F}
    Born	text	{}
    Contact	text	{}

}

## Check dir content on update
Operation Person::_update_ {} {
    
    check::reset Fatal Warning

    check::attribute Fatal Name
    check::attribute Warning Role
    check::attribute Warning Sex
    
    return [ check::requires_propagation $Fatal ]
}


## Exports person data
Operation Person::export {} {

    puts [ format {%30s %30s} $Name $Role ]
}

Operation Person::certificate:show ? {

    puts [ ${_Self_} certificate ]
}

## Prints certificate for this person
Operation Person::certificate:print ! {

    set groups  [ file::canonical_pathname ${_Self_}/../../.. ]
    set gps     [ data::open $groups ]
    set printer [ set ${gps}::Printer ]
    set config  ${_Self_}/../../../[ set ${gps}::Config ]

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

## Returns a string with the HTML formatting for this person
Operation Person::certificate {} {

    set groups [ file::canonical_pathname ${_Self_}/../../.. ]
    set group  [ file::canonical_pathname ${_Self_}/../.. ]
    set team [ file::canonical_pathname ${_Self_}/.. ]

    set grs [ data::open $groups ]
    set gr  [ data::open $group  ]
    set tm  [ data::open $team  ]

    set Person_template	[ set ${grs}::Person_template ]    

    set classifier [ classify::classifier ]

    if { ! [ file exists $groups/$Person_template ] } {
	layout::alert "Missing person certificate layout"
	return
    }

    regsub -all {_} [ set ${tm}::Name ] { } name

    namespace eval data [ list set Group [ set ${gr}::Designation ] ]
    namespace eval data [ list set Team	$name ]
    namespace eval data [ list set Rank  \
			      [ $classifier [ set ${tm}::Rank ] $Sex ] ]
    namespace eval data [ list set Name 	$Name ]
    namespace eval data [ list set Role	$Role ]

    return [ namespace eval data \
		 [ list subst -nocommands \
		       [ file::read_in $groups/$Person_template ] ] ]
    
}
