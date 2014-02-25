#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Groups.tcl
# 
## Group of teams (typically an university) in a contest
##

package provide Group 1.0

package require data

namespace eval Group {
    
    # iso3166-countrycodes
    variable Flags {
	00  be  cl  ec  gu  ir  lb  mx  pe  sa  tw  za
	ad  
	ae  bh  cn  ee  hk  is  lk  my  ph  sb  ua  zm
	ag  bm  co  eg  hn  it  lt  mz  pk  se  ug  zw
	am  bn  cr  es  hr  jm  lv  na  pl  sg  uk
	ao  bo  cu  fi  hu  jo  ma  ng  pr  si  us
	ar  br  cy  fo  id  jp  mo  ni  pt  sk  uy
	at  bs  cz  fr  ie  ke  mp  nl  py  sr  vc
	au  by  de  gb  il  kr  mt  no  qa  th  ve
	bb  ca  dk  gr  in  kw  mu  nz  ro  tr  vi
	bd  ch  do  gt  iq  kz  mw  pa  ru  tt  yu
    }

    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Designation	"Group name"
	Acronym		"Group Acronym"
	LDAP		"Use LDAP for authentication"
	
    }

}


Attributes Group 						\
    [ list							\
	  Fatal		fatal	{}				\
	  Warning	warning {}				\
	  							\
	  Designation	text	{}				\
	  Acronym	text	{}				\
	  Color		text	{}				\
	  Flag 		ref	{data/configs/flags}		\
	  Team 		dirs	Team				\
	  Authentication choice {Basic status {} LDAP ref {data/configs/ldap} }	\
     ]
		   
## Initializes a group
Operation Group::_create_ {} {
    
    set Designation [ file tail ${_Self_} ]
    set Acronym [ file tail ${_Self_} ]
    set Flag	00
    set Color	Black
}

## Check group after update
Operation Group::_update_ {} {

    check::reset Fatal Warning

    check::attribute Fatal Designation
    check::attribute Fatal Acronym
    foreach attr { Color Flag} {
	check::attribute Warning $attr
    }

    set n 0
    foreach path [ glob -nocomplain -type d ${_Self_}/* ] {
	set team [ file tail $path ]
	check::attribute Fatal $team dir
	incr n
    }
    if { $n == 0 } {
	check::record Fatal simple "No teams in this group"
    }

    switch $Authentication {
	LDAP {
	    check::attribute Fatal LDAP
	}
    }

    return  [ check::requires_propagation $Fatal ]
}


## DEPRECATED
# Propagates checks to sub-dirs
Operation Group::check {} {

    check::dir_start
    check::vars Designation Color Flag
    check::sub_dirs
    check::dir_end
}

## Export group in text format
Operation Group::export {} {
    
    puts [ format {%5s %20s} $Acronym $Designation ]
    foreach team [ glob -type d -nocomplain ${_Self_}/* ] {
	data::open $team
	$team export 
    }
}




## Generate passwords of all teams to an archive
Operation Group::passwords:generate-to-archive ! {

    set contest ${_Self_}/../..
    set groups	${_Self_}/..
    set dir	${_Self_}
    set pattern ${_Self_}/*

    Groups::generate_passwords_to_archive $contest $groups $dir $pattern

    layout::alert "Passwords generated" 
    content::show ${_Self_}
}

## Generate passwords of all teams to an excel
Operation Group::passwords:Export-to-excel ! {

    set contest ${_Self_}/../..
    set groups	${_Self_}/..
    set dir	${_Self_}
    set pattern ${_Self_}/*

    Groups::generate_passwords_to_excel $contest $groups $dir $pattern

    #layout::alert "Passwords generated" 
    content::show ${_Self_}
}

# Menu callback to clean the cache in all teams in this group
Operation Group::cache:clean ! {

    set count 0
    foreach team [ glob -nocomplain -type d ${_Self_}/* ] {
	data::open $team
	$team cache_clean
	incr count
    }
    
    layout::alert [ format "Chache cleaned in %d teams" $count ]
    content::show ${_Self_}    
}


# Menu callback to set now start time in all teams of this group
Operation Group::start:now ! {

    set now  [ clock seconds ] 

    set count 0
    foreach team [ glob -nocomplain -type d ${_Self_}/* ] {
	set td [ data::open $team ]
	set ${td}::Start [ list $now ]
	data::record $team
	incr count
    }
    
    layout::alert [ format "Set start time now in %d teams" $count ]
    content::show ${_Self_}    
}

# Menu callback to reset start time in all teams of this group
Operation Group::start:reset ! {

    set count 0
    foreach team [ glob -nocomplain -type d ${_Self_}/* ] {
	set td [ data::open $team ]
	set ${td}::Start ""
	data::record $team
	incr count
    }
    
    layout::alert [ format "Reset start time in %d teams" $count ]
    content::show ${_Self_}

    
}