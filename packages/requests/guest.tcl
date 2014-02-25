#
# Mooshak: managing  programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: guest.tcl
# 
## Requests common to several profiles (admin judge runner team guest) 
## These procs receive data from the command line and CGI variables
## and generate HTML layout in the stdout.
## Most quest request are common to other profiles. In fact they are
## crippled versions of those used for runner and judge.
## The only task  specific to guests is registration.

package provide guest 1.0


namespace eval guest {

    variable GroupMenuSize 10

    array set FormData {
	contest	""
	name	""
	email	""
	group	""
    }

}

## Team registration form processing
proc guest::register args {
    variable ::Session::Conf
    variable FormData

    set data 0
    foreach var [ array names FormData ] {
	if { [ set value [ cgi::field $var "" ] ] != "" } {
	    set FormData($var) $value
	} 
    }

    create_menus

    set message [ translate::sentence [ check_registation_data ] ]     

    template::load
    
    if { $message == "" }  {   
	mk_new_user
	template::write show
    } else {
	
	template::write form
    }
}

proc guest::flag {code} {

    set fd [ open "data/configs/flags/$code/$code.png" r ]
    fconfigure $fd -translation binary
    fconfigure stdout -translation binary
    fcopy $fd stdout
    close $fd
}


proc guest::create_menus {} {
    variable GroupMenuSize
    variable FormData

    # make contest menu

    data::open data/contests

    set active 1	;# only active contests are showed
    set update 1	;# update on contest selection
    set registrable 1	;# don't include non registrable contests

    set FormData(contest_selector) [ data/contests selector FormData(contest) \
					 $active $update $registrable ]

    #make groups menu (depending on having a contest)
    if { $FormData(contest) == "" } {
	set FormData(designation) ""
	set FormData(groups_menu) \
	    [ layout::menu group {} {} {}  $GroupMenuSize {} ]
    } else {
	
	set contest data/contests/$FormData(contest)
	set cnt [ data::open $contest ]
	set FormData(designation)	[ set ${cnt}::Designation ]
	set FormData(from) 		[ set ${cnt}::Email ]
	set FormData(groups)  	        $contest/groups
	data::open $FormData(groups)
	set FormData(groups_menu) [ layout::menu group \
					[ lsort [$FormData(groups) groups] ] \
					$FormData(group) {} $GroupMenuSize {} ]
    }
    
}


## 
proc guest::check_registation_data {} {
    variable FormData

    set contest data/contests/$FormData(contest)

    set data 0
    if { $FormData(contest) == "" } {
	return "Select a contest first"
    } elseif { [ data::open $contest ] != {} && ! [ $contest registrable ] } {
	# should never reach this point
	return "Connot register in selected contest"
    } elseif { $FormData(name) == "" } {
	return "Missing team name"
    } elseif { ! [ regexp {^\w+$} $FormData(name) ] } {
	return "Invalid chars in name"
    } elseif { $FormData(email) == "" } {
	return "Missing email"
    } elseif { ! [ email::valid $FormData(email) ]  } {
	return "Wrong email address"
    } elseif { $FormData(group) == "" } {
	return "Missing group"
    } elseif { [ set FormData(group_dir) 				 \
		     [ $FormData(groups) search_group $FormData(group) ] \
		    ] == "" } {
	return "Invalid group"
    } elseif {  [ $FormData(groups) search_team $FormData(name) ] > -1 } {
	return "Team name already exists"
    } else {
	return ""
    }
}


## Create a new dir for user with FormData
proc guest::mk_new_user {} {
    variable FormData

    # generate dir for new user
    regsub -all { } [ string trim $FormData(name) ] {_} root
    set fx $FormData(group_dir)/$root
    
    set FormData(password) [ password::generate ]
    
    set se [ data::new $fx Team ]
    set ${se}::Name $FormData(name)
    set ${se}::Email $FormData(email)
    set ${se}::Password [ Session::crypt $FormData(password) ]
    set ${se}::Qualifies no
    
    data::record $fx
    
    # give the class a chance to make updates
    set FormData(name) 		[ set ${se}::Name ]
    
    foreach lang [ translate::langs ] {
	set frm templates/$lang/guest/send_password.txt
	if [ file readable $frm ] {
	    break
	}
    }
    
    email::send $FormData(from) $FormData(email) $frm \
	data/contests/$FormData(contest)/groups/mail_log
}
