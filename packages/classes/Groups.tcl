#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file:  Groups.tcl
# 
## Groups of teams in contest
#
## TODO: improve import/export

package provide Groups 1.0

package require data
package require print
package require Team

namespace eval Groups {
    variable ArchiveName passwords
    variable ArchiveType tgz


    variable ColumnNames { - 
	id role first_name last_name name 
	group acronym team email 
	gender country flag color status password }

}

Attributes Groups {

    Fatal	fatal	{}
    Warning	warning {}

    Printer		text	{}
    Team_template	fx	{.html}
    Person_template	fx	{.html}
    Password_template	fx	{.html}
    Config		fx	{.css}
    Group		dirs	Group

}

## Check dir content on update
Operation Groups::_update_ {} {

    check::reset Fatal Warning

    switch [ check::dirs fatal ${_Self_} ] {
	0 {	    check::record Fatal simple "No groups defined"	  }
	1 {	    check::record Warning simple "Just one group defined" }
	
    }

    set files {}
    foreach file [ list 			\
		       Team_template 		\
		       Person_template 		\
		       Password_template	\
		       Config			\
		      ] {
	if { ! [ file readable ${_Self_}/[ set $file ] ] } {
	    ${_Self_} make_default_file $file
	    lappend files $file
	}
    }

    if { $files != {} } {
	layout::alert "created default [ join $files {, } ]"
    }

    return [ check::requires_propagation $Fatal ]
}

## Sets default printer
Operation Groups::defaults:printer ! {
    set Printer [ print::default_printer ]
    data::record ${_Self_}
    content::show ${_Self_}
}

## Creates a default HTML template to format contestants certificates
Operation Groups::defaults:person_template ! {
    ${_Self_} create_file Person_template
}

## Creates a default HTML template to format team certificates
Operation Groups::defaults:team_template ! {
    ${_Self_} create_file Team_template
}

## Creates a default HTML template to format  password sheets
Operation Groups::defaults:password_template ! { 
    ${_Self_} create_file Password_template
}

# Crates a default CSS config file  for HTML to PS conversion
Operation Groups::defaults:config ! {     ${_Self_} create_file Config }


Operation Groups::create_file {type} {
    
    ${_Self_} make_default_file $type
    layout::alert "Default $type created"
    content::show ${_Self_} 1
}


Operation Groups::make_default_file {type} {

    set fd [ open ${_Self_}/[ set $type ] w ] 
    switch $type {
	Config {
	    puts $fd {
		@html2ps {
		    paper {
			type: a4;
		    }       
		    option {
			landscape: 1;
		    }
		}
		/* use CSS2 blocks to configure HTML elements */
		@page {
		    margin-left:   2.5cm;
		    margin-right:  2.5cm;
		    margin-top:    7.5cm;
		    margin-bottom: 5.0cm;
		}
		
		BODY {  font-size:      24pt;   }
		H1 {    font-size:      36pt;   }
		H2 {    font-size:      32pt;   }
		H3 {    font-size:      18pt;   }
		
	    }
	}
	Person_template {
	    puts $fd {
		<table width="100%" border="0">
		<tr><th><h1><u>$Rank</u></h1><br></th><tr>
		<tr><th><h1>$Name</h1><br></th></tr>
		<tr><th><h2>Team "$Team"</h2></th></tr>
		<tr><th><h3>$Group</h3></th><tr>
		</table>
	    }
	}
	Team_template {
	    puts $fd {
		<table width="100%" border="0">
		<tr><th><h1><u>$Rank</u></h1></th><tr>
		<tr><th><h1>Team "$Team"</h1></th></tr>
		<tr><th><h2>$Group</h2></th><tr>
		<tr><th><h3>$Names</h3></th></tr>
		</table>
	    }
	}
	Password_template {
	    puts $fd {
		<table width="100%" border="0">
		<tr><th colspan="2" height="100">&nbsp;</th></tr>
		<tr><th colspan="2"><h1>$Contest</h1></th></tr>
		<tr><th colspan="2" height="200">&nbsp;</th></tr>
		<tr><th>Team</th><td>$Team</td></tr>
		<tr><th>Group</th><td>$Group</td></tr>
		<tr><th colspan="2" height="200">&nbsp;</th></tr>
		<tr><th>Login</th><td>$Login</td></tr>
		<tr><th>Password</th><td>$Password</td></tr>
		</table>
	    }
	}
    }
    close $fd     
}




## Propagates cheks to all sub-directories
Operation Groups::check {} {
    
    check::dir_start 1
    switch [ check::sub_dirs ] {
	0	{ check::report_error Fatal "No group defined" 	  }
	1	{ check::report_error Warning "Just one group defined" }
	default {}
    }
    check::dir_end 1
}


## Returns list of group names
Operation Groups::groups {} {
    set groups {}
    foreach group [ glob -type d -nocomplain ${_Self_}/* ] {
	set sg [ data::open $group ]
	lappend groups [ set ${sg}::Designation ]
    }
    return $groups
}

## Search group by name (designation), returns pathname
Operation Groups::search_group {name} {

    set name [ string trim $name ]
    foreach group [ glob -type d -nocomplain ${_Self_}/* ] {
	set sg [ data::open $group ]
	if { [ string equal [string trim [set ${sg}::Designation] ] $name ] } {
	    return $group
	}
    }
    return {}
}


## Search team by name, returns pathname
Operation Groups::search_team {name} {

    set name [ string trim $name ]
    foreach team [ glob -type d -nocomplain ${_Self_}/*/* ] {
	set sg [ data::open $team ]
	if { [ string equal [ set ${sg}::Name ] $name ] }  {
	    return $team
	}
    }
    return {}
}

## Returns list of team ids
Operation Groups::team_ids {} {

    set teams {}
    foreach path [ glob -type d -nocomplain ${_Self_}/*/* ] {
	lappend teams [ file tail $path ]
    }

    return $teams
}

## DEPORECATED ?
## Returns list of team names
Operation Groups::teams {} {

    set teams {}
    foreach group [ glob -type d -nocomplain ${_Self_}/* ] {
	set sg [ data::open $group ]
	foreach team [ glob -type d -nocomplain $group/* ] {
	    set st [ data::open $team ]
	    if [ info exists ${st}::Name ] {
		lappend teams [ set ${st}::Name ]
	    }
	}
    }
    return $teams
}

## Returns values of group and team vars for given team id
Operation Groups::identify {team_id group_vars team_vars} {
    
    set values {}    

    if {
	$team_id != "" &&
	[ regexp [ format {%s/(.*)/%s} ${_Self_} ${team_id} ]		\
	       [ glob -type d -nocomplain ${_Self_}/*/${team_id} ]	\
	       - group ] 
     } {
	set sg [ data::open ${_Self_}/$group ]		
	foreach var $group_vars {
	    if [ info exists ${sg}::${var} ] {
		lappend values  [ set ${sg}::${var} ]
	    } else {
		    lappend values {}
	    }
	}
	if { [ file isdirectory ${_Self_}/$group/$team_id ] } {
	    set st [ data::open ${_Self_}/$group/$team_id ]	
	    foreach var $team_vars {
		if [ info exists ${st}::${var} ] {
		    lappend values  [ set ${st}::${var} ]
		} else {
		    lappend values {}
		}
	    }
	} else {
	    foreach var $team_vars	{ lappend values ? }
	}
    } else {
	
	foreach var $group_vars	{ lappend values ? }
	foreach var $team_vars	{ lappend values ? }
	
    }
    
    foreach {var default} {Flag 00 Color \#666666 } {
	if { 
	    [ set p [ lsearch $group_vars $var ] ] > -1 &&
	    [ string length [ lindex $values $p ] ] < 2 
	} {
	    set values [ lreplace $values $p $p $default ]
	}
    }

    return $values
}

## DEPRECATED !!
## Returns group of a team
Operation Groups::group {team_name} {

    foreach group [ glob -type d -nocomplain ${_Self_}/* ] {
	set sg [ data::open $group ]
	foreach team [ glob -type d -nocomplain $group/* ] {
	    set st [ data::open $team ]	  
	    if { [ string compare [ set ${st}::Name ] $team_name ] == 0 } {
		return [ file tail $group ]
	    }
	}
    }
    return ""
}

## There is a team with this login
Operation Groups::group_of_team {team_id} {

    if [ regexp [ format {%s/(.*)/%s} ${_Self_} ${team_id} ]	\
	     [ glob -type d -nocomplain ${_Self_}/*/${team_id} ]	\
	     - group ] {
	return $group
    } else {
	return ""
    }
}


## Exports groups in text format
Operation Groups::data:export ? {

    puts <pre>
    foreach group [ glob -type d -nocomplain ${_Self_}/* ] {
	data::open $group
	$group export
    }
    puts </pre>
}


## Print all certificates in reverse order
Operation Groups::certificates:check ! {     

    set msgs {}
    foreach team [ glob -type d -nocomplain ${_Self_}/*/* ] {
	set t [ data::open $team ]
	set cp [ print::data [ $team certificate ] COUNT ${_Self_}/$Config ]
	if { $cp != 1 } {
	    set team_name [ set ${t}::Name ]
	    lappend msgs "Team certificate with $cp pages: $team_name"
	}
	foreach person [ glob -type d -nocomplain ${team}/* ] {
	    set p [ data::open $person ]
	    set cp [print::data [$person certificate] COUNT ${_Self_}/$Config]
	    if { $cp != 1 } {
		set person_name [ set ${t}::Name ]
		lappend msgs "Person certificate with $cp pages: $person_name"
	    }
	}
    }    

    if { $msgs == {} } {
	layout::alert "Certificates seam to be OK"
    } else {
	layout::alert [ join $msgs \n ]
    }
    content::show ${_Self_}
}

## Print all certificates in reverse order
Operation Groups::certificates:print ! {    
    variable ranking_of
    variable directory_of

    ${_Self_} consolidate

    foreach team_name [ lsort -command Groups::cmp_ranking \
		       [ array names ranking_of ] ] {

	set team $directory_of($team_name)
	
	data::open $team
	print::data [ $team certificate ] $Printer ${_Self_}/$Config
	foreach person [ glob -type d -nocomplain ${team}/* ] {
	    data::open $person
	    print::data [ $person certificate ] $Printer ${_Self_}/$Config
	}
    }    
    
    layout::alert "Certificates printed"
    content::show ${_Self_}
    
}

## Print all certificates in reverse order in single printer job
Operation Groups::certificates:print-single-job ! {    
    variable ranking_of
    variable directory_of

    ${_Self_} consolidate

    set job ""
    set sep ""
    foreach team_name [ lsort -command Groups::cmp_ranking \
		       [ array names ranking_of ] ] {

	set team $directory_of($team_name)
	
	data::open $team
	append job $sep
	append job [ $team certificate ] 
	set sep \n<!--NewPage-->\n
	foreach person [ glob -type d -nocomplain ${team}/* ] {
	    data::open $person
	    append job $sep
	    append job [ $person certificate ] 
	}
    }    
    print::data $job $Printer ${_Self_}/$Config

    layout::alert "Certificates printed"
    content::show ${_Self_}
    
}



## Consolidate rankings 
Operation Groups::certificates:consolidate ! {    

    ${_Self_} consolidate

    layout::alert "Ranking updated"

    content::show ${_Self_}
}

# Compare ranking of two given teams 
proc Groups::cmp_ranking {a b} {
    variable ranking_of
    
    return [ expr $ranking_of($a) > $ranking_of($b) ]
}

## Consolidate rankings before printing certificates
Operation Groups::consolidate {} {    
    variable ranking_of
    variable directory_of

    set debugging 0

    set subs [ file::canonical_pathname ${_Self_}/../submissions ]
    data::open $subs
    $subs ranking 1 1

    if $debugging { template::load }

    set teams {}
    foreach gfx [ glob -nocomplain -type d ${_Self_}/* ] {
	set gr [ data::open $gfx ]

	set institution	[ set ${gr}::Designation ]	

	foreach tfx [ glob -nocomplain -type d $gfx/* ] {
	    set tm [ data::open $tfx ]	    
	    
	    lappend teams [ set team [ set ${tm}::Name ] ]
	    set tfx_of($team) $tfx
	    set institution_of($team)		$institution
	    
	    if { [ regexp {^\d+$} [ set ${tm}::Rank ] ] } {
		set ranking_of($team)	[ set ${tm}::Rank ] 
	    } else {
		set ranking_of($team) 0
	    }
	    set directory_of($team) $tfx
	    
	    set persons($team) {}
	    foreach pfx [ glob -nocomplain -type d $tfx/* ] {
		set ps [ data::open $pfx ]	    
		
		# uncomment to avoid printing certificates for coches
		#if [ string equal [ set ${ps}::Role ] Coach ] continue

		lappend persons($team) [ set ${ps}::Name ]
		set pfx_of($team,[ set ${ps}::Name ]) $pfx
	    }
	}
    }

    set classifier [ classify::classifier ]
    if $debugging { template::write head }
    foreach team [ lsort -command Groups::cmp $teams ] {
	set institution $institution_of($team)
	set ranking [ $classifier $ranking_of($team) ]
	set tfx $tfx_of($team)
	if $debugging { template::write team }

	foreach person $persons($team) {
	    set pfx $pfx_of($team,$person)
	    if $debugging { template::write person }
	}
	if $debugging { template::write end_team }
    }
    if $debugging { template::write foot }

}

## Compares groups bases on ranking; used in lsort
proc Groups::cmp {a b} {
    variable ranking_of 

    if { $ranking_of($a) == 0 } {
	return -1
    } elseif { $ranking_of($b) == 0 } {
	return 1
    } else {
	return [ expr $ranking_of($b) - $ranking_of($a) ]
    }
}

## Import form a uploaded file
Operation Groups::data:import ? {
    global REL_BASE
    
    set dir ${_Self_} 
    template::load
    template::write 
}

## importing data from teams
Operation Groups::importing args {
    variable ::file::TMP

    set dir $args

    set reset  [ cgi::field "reset" 0 ]
    set filename  [ cgi::field "file" {} ]
    if { $filename == {} } {
	set data  [ cgi::field "data" {} ]

	set operation [ cgi::field "operation" "parse" ]
	set sep	      [ cgi::field "sep" "\t" ]
	set ommit     [ cgi::field "ommit" "0" ]
	set generate  [ cgi::field "generate" "0" ]
	

	set columns   {}
	set index 0 
	while { [ set column [ cgi::field "column_$index" {} ] ] != {} } {
	    lappend columns $column
	    incr index
	}

    } else {
	set data [ file::read_in $TMP/$filename ]
	guess_data_parameters $data sep ommit generate columns
	set operation "parse"
    }

    if $reset {
	foreach group [ glob -nocomplain -type d ${_Self_}/* ] {
	    file delete -force $group
	}
    }


    ${_Self_} $operation $data $sep $ommit $generate $columns

}


proc Groups::guess_data_parameters {data sep_ ommit_ generate_ columns_} {
    upvar $sep_      sep
    upvar $ommit_    ommit
    upvar $generate_ generate
    upvar $columns_  columns

    set ommit 0
    set generate 1
    set nlines [ llength [ split $data \n ] ]

    ## guess separator
    foreach sep { \t , ; \t } {
	set ncell [ llength [ split $data $sep ] ]
	set ncols [ expr $ncell / $nlines  + 1 ];
	if { $ncols > 1 }  break
    }


    set header  [ split [ lindex [ split $data \n ] 0 ] $sep ]
    set columns [ string trim [ string  repeat "- " [ llength $header ] ] ]
    set pos 0

    foreach head $header {

	## patterns that may have name in it must appear first
	foreach {pattern column} { 	    
	    password	password
	    color	color
	    role 	role
	    team 	team 
	    group	group
	    institution group
	    "first name" first_name
	    "last name"  last_name
	    name	 name
	    nome	 name
	    email 	 email 
	    NCD		team
	    number	team
	    número	team
	    gender 	gender
	    sex 	gender
	    turma	group
	    country	country
	    flag	flag
	    acronym	acronym
	    sigla	acronym
	    status	status
	    id		id
	} {

	    if { [ regexp -nocase $pattern $head ] } {
		set columns [ lreplace $columns $pos $pos $column ]
		set ommit 1
		break
	    }
	}
	incr pos
    }

    if { [ lsearch $columns id ] > -1 } {
	set generate 0
    }
}

Operation Groups::parse {data sep ommit generate columns} {
    variable ColumnNames

    set dir ${_Self_}

    set sep_selector [ layout::menu sep { \t , ; } $sep { \\t , ; }]
    if $ommit {
	set start 1
	set ommit_checked checked 
    } else { 
	set start 0
	set ommit_checked "" 
    }
    if $generate {
	set generate_checked checked 
    } else {
	set generate_checked ""
    }

    regsub -all \r $data {} data 
    set header  [ split [ lindex [ split $data \n ] 0 ] $sep ]

    template::load

    template::write head

    template::write line_head
    if $generate {
	    template::write column_id
    }

    set index 0
    foreach column $columns {

	if $ommit {  
	    set head [ lindex $header $index ]
	} else {
	    set head ""
	}
	set selector [ layout::menu column_$index $ColumnNames $column ]
	template::write column_head
	incr index
    }
    set id 0
    template::write line_foot
    foreach line [ lrange [ split $data \n ] $start end ] {
	template::write line_head
	if $generate {
	    set cell [ incr id ]
	    template::write line_cell
	}
	foreach cell [ split [ string trim $line ] $sep ] {
	    template::write line_cell
	}
	template::write line_foot

    }

    template::write foot
}


## Import CSV data with given features 
Operation Groups::import {data sep ommit generate columns} {
    variable ::Session::Conf
    variable ColumnNames

    if { [ lsearch $columns team ] == -1 } {
        puts "<h1>No column <code>team</code> selected</h1>"
        puts "<p>Go back, select a <code>team</code> column and resubmit</p>"
        return
    }

    set debug 1    

    set id 0

    if $ommit { set start 1 } else { set start 0 } 
    foreach line [ lrange [ split $data \n ] $start end ] {

	foreach field [ lreplace $ColumnNames 0 1 {} ] { set $field "" }

	foreach $columns [ split [ string trim $line ] $sep ] {}

	foreach field $columns {
	    set $field [ string trim [ set $field ] ]
	}

	## ignore empty lines 
	if { $team == "" } continue       

	if $generate { incr id }

	if {[info exists first_name] && [info exists last_name] && $name=="" } {
	    set name "$first_name $last_name"
	}

	set name_of($id) $name
	set role_of($id) [ string totitle $role ]
	set email_of($id) $email
	set gender_of($id) [ string toupper [ string index $gender 0 ] ]

	if { [ regexp {^\d+$} $team ] } {
	    set name_of($team) $name
	} else {
	    set name_of($team) $team
	}
	
	if { $password != "" } {
	    set password_of($team) [ Session::crypt $password ]
	} else {
	    set password_of($team) ""
	}

	if { $group == "" } {
	    set group "Default"
	    set name_of($group) "Default group"
	} else {
	    set name_of($group) $group
	}

	if { $acronym == "" } {
	    set acronym_of($group) [ etc::acronym $group ] 
	} else {
	    set acronym_of($group) $acronym
	}

	if { $color == "" } {
	    set color_of($group) black
	} else {
	    set color_of($group) $color
	}
	
	if { $flag == "" } {
	    set flag_of($group) 00
	} else {
	    set flag_of($group) $flag
	}

	etc::accumulate groups $group
	etc::accumulate teams($group) $team
	etc::accumulate ids($team) $id

    }

    # read in registered data
    set reg_groups {}
    foreach gfx [ glob -nocomplain -type d ${_Self_}/* ] {
	set gr [ data::open $gfx ]
	lappend reg_groups [ set group [ set ${gr}::Designation ] ]
	set path($group) $gfx
	set reg_teams($group) {}
	foreach tfx [ glob -nocomplain -type d $gfx/* ] {
	    set tm [ data::open $tfx ]	    
	    lappend reg_teams($group)  [ set team [ set ${tm}::Name ] ]
	    set path($team) $tfx
	    set reg_persons($team) {}
	    foreach pfx [ glob -nocomplain -type d $tfx/* ] {
		set ps [ data::open $pfx ]	    
		lappend reg_persons($team)  [ set person [ set ${tm}::Name ] ]
		set path($person) $pfx
	    }
	}
    }

    # create missing data

    set lang [ lindex [ translate::langs ] 0 ]
    data::open data/configs/flags
    if [ data/configs/flags exists $lang ] {
	set flag $lang
    } else {
	set flag 00
    }

    if $debug { puts "<ul>" }
    foreach group $groups {
	if { [ lsearch $reg_groups $group ] == -1 } {
	    if $debug { puts "<li>$group" }

	    set n 1
	    while { [ file isdirectory ${_Self_}/$acronym_of($group) ] } {
		regsub [ format {%d$} $n ] $acronym_of($group) {} acronym_of($group)
		append acronym_of($group) [ incr n ]
	    }
	    set gfx ${_Self_}/$acronym_of($group)

	    set gr [ data::new $gfx Group ]

	    set ${gr}::Designation $name_of($group)
	    set ${gr}::Acronym $acronym_of($group)
	    set ${gr}::Flag $flag_of($group)
	    set ${gr}::Color $color_of($group)
	    data::record $gfx

	    set reg_teams($group) {}
	} else {
	    set gfx $path($group)
	}
	if $debug { puts "<ul>" }
	foreach team $teams($group) {
	    if { [ lsearch $reg_teams($group) $team ] == -1 } {
		if $debug { puts "<li>$team" }

		set tfx $gfx/[ file::valid_dir_name $team ] 
		set tm [ data::new $tfx Team ]
		set ${tm}::Name $name_of($team)
		if { $password_of($team) == "" } {
		    set ${tm}::Password [ password::generate ]
		} else {
		    set ${tm}::Password $password_of($team)
		}
		data::record $tfx

		set reg_persons($team) {}
	    } else {
		set tfx $path($team)
	    }
	    if $debug { puts "<ul>" }
	    foreach id $ids($team) {
		if { [ lsearch $reg_persons($team) $id ] == -1 } {
		    if $debug { puts "<li>$name_of($id) $role_of($id)" }

		    set pfx $tfx/[ file::valid_dir_name $id ] 
		    set ps [ data::new $pfx Person ]
		    set ${ps}::Name $name_of($id)
		    set ${ps}::Role $role_of($id)
		    set ${ps}::Sex $gender_of($id)
		    set ${ps}::Contact $email_of($id)

		    if { 
			[ string equal $lang "pt" ] && 
			[ regexp {^\w+a\s} $name_of($id) ] 
		    } {
			# when language is in portuguese, 
			# infer sex as femele if first word of name end with "a"
			set ${ps}::Sex F
		    }

		    data::record $pfx		    
		} 
	    }
	    if $debug { puts "</ul>" }
	}
	if $debug { puts "</ul>" }
    }
    if $debug { puts "</ul>" }

    layout::window_close_after_waiting
    layout::window_open $Conf(controller)?data+${_Self_} select 0
}


## Print passwords of all teams
Operation Groups::passwords:to-printer ! {

    set contest [ file::canonical_pathname ${_Self_}/.. ]
    set cnt [ data::open $contest ]
    set name [ set ${cnt}::Designation ]
        
    foreach tm [ glob -type d -nocomplain ${_Self_}/*/* ] {
	data::open $tm
	print::data \
	    [ $tm password_sheet $name ${_Self_}/$Password_template ] \
	    $Printer $Config
	
    }    

    layout::alert "Passwords printed" 
    content::show ${_Self_}
}

## Prin passwords of all teams as a single printing job
Operation Groups::passwords:to-printer-single-job ! {

    set contest [ file::canonical_pathname ${_Self_}/.. ]
    set cnt [ data::open $contest ]
    set name [ set ${cnt}::Designation ]

    set job ""
    set sep ""
    foreach tm [ glob -type d -nocomplain ${_Self_}/*/* ] {
	data::open $tm
	append job $sep
	append job [ $tm password_sheet $name ${_Self_}/$Password_template ]
	set sep \n<!--NewPage-->\n
    }    
    print::data $job $Printer $Config

    layout::alert "Passwords printed" 
    content::show ${_Self_}
}

## Generate passwords of all teams to an archive
Operation Groups::passwords:to-archive ! {

    set contest ${_Self_}/..
    set groups	${_Self_}
    set dir	${_Self_}
    set pattern ${_Self_}/*/*
    generate_passwords_to_archive $contest $groups $dir $pattern

    layout::alert "Passwords generated" 
    content::show ${_Self_}
}


proc Groups::generate_passwords_to_archive {contest groups dir pattern} {
    variable ::Session::Conf
    variable ArchiveName 
    variable ArchiveType
    variable ::file::TMP

    ## get variables from contest and groups folders
    set contest [ file::canonical_pathname $contest ]
    set cnt [ data::open $contest ]
    set name [ set ${cnt}::Designation ]

    set groups [ file::canonical_pathname $groups ]
    set grp [ data::open $groups ]
    set template $groups/[ set ${grp}::Password_template ]
    set config [ set ${grp}::Config ]

    foreach tm [ glob -type d -nocomplain $pattern ] {
	data::open $tm

	set team  [ file tail $tm ]
	set group [ file tail [ file dirname $tm ] ]

	print::set_output_file $TMP/${group}_${team}.ps 
	print::data [ $tm password_sheet $name $template ] FILE $config	
    }    

    ## generate zip file
    set here [ pwd ]
    set archive $ArchiveName.$ArchiveType
    set command [ file::archive_command $archive ]
    cd $TMP
    if [ catch { eval exec $command $here/$dir/$archive . } msg ] {
	cd $here
	layout::alert $msg

	content::show $dir
    } else {
	cd $here
	#layout::alert "Passwords archive generated" 

	layout::window_close_after_waiting
	layout::window_open $Conf(controller)/$dir/$archive select 0
    }
    
}



## Generate password archive and extract passwors to excel file
proc Groups::generate_passwords_to_excel {contest groups dir pattern} {

	variable ::Session::Conf
    variable ArchiveName 
    variable ArchiveType
    variable ::file::TMP

    ## get variables from contest and groups folders
    set contest [ file::canonical_pathname $contest ]
    set cnt [ data::open $contest ]
    set name [ set ${cnt}::Designation ]

    set groups [ file::canonical_pathname $groups ]
    set grp [ data::open $groups ]
    set template $groups/[ set ${grp}::Password_template ]
    set config [ set ${grp}::Config ]

    foreach tm [ glob -type d -nocomplain $pattern ] {
	data::open $tm

	set team  [ file tail $tm ]
	set group [ file tail [ file dirname $tm ] ]

	print::set_output_file $TMP/${group}_${team}.ps 
	print::data [ $tm password_sheet $name $template ] FILE $config	
    }    

    ## generate zip file
    set here [ pwd ]
    set archive $ArchiveName.$ArchiveType
    set command [ file::archive_command $archive ]
    cd $TMP
    if [ catch { eval exec $command $here/$dir/$archive . } msg ] {
	cd $here
	layout::alert $msg

	content::show $dir
    } else {
	cd $here
	set xname login.xls
	##generating excel file
     	exec /bin/bash contrib/password_extraction.sh $dir
	set arj $dir/$xname


#	layout::window_close_after_waiting
#	layout::window_open $Conf(controller)/$dir/$xname select 0


	puts [ format {<html><body><form><a href="%s" target="_blank">Right click and Save the Link As</a></form></body></html>} $arj ]
	}        	
}



# Menu callback to clean the cache in all teams on all groups
Operation Groups::cache:clean ! {

    set count 0
    foreach team [ glob -nocomplain -type d ${_Self_}/*/* ] {
	data::open $team
	$team cache_clean
	incr count
    }
    
    layout::alert [ format "Chache cleaned in %d teams" $count ]
    content::show ${_Self_}
}

# Menu callback to set now start time in all teams on all groups
Operation Groups::start:now ! {

    set now [ clock seconds ]

    set count 0
    foreach team [ glob -nocomplain -type d ${_Self_}/*/* ] {
	set td [ data::open $team ]
	set ${td}::Start $now
	data::record $team
	incr count
    }
    
    layout::alert [ format "Set start time now in %d teams" $count ]
    content::show ${_Self_}    
}

# Menu callback to reset start time in all teams on all groups
Operation Groups::start:reset ! {

    set count 0
    foreach team [ glob -nocomplain -type d ${_Self_}/*/* ] {
	set td [ data::open $team ]
	set ${td}::Start ""
	data::record $team
	incr count
    }
    
    layout::alert [ format "Reset start time in %d teams" $count ]
    content::show ${_Self_}

    
}