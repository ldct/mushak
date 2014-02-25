#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Users.tcl
# 
## Mooshak user (excluding teams): admin, judge, runner
##

package provide User 1.0

package require data

namespace eval User {
    # valid profiles (guest does need auth.)
    variable Profiles {admin judge runner exam} 
}

Attributes User [ list							\
		      Name	text		{}			\
		      Password	password	{}			\
		      Profile	ref		{data/configs/profiles}	]


Operation User::_create_ {} {
    variable Profiles

    set Name [ file tail ${_Self_} ]
    foreach profile $Profiles {
	if [ regexp $profile $Name ]  {
	    set Profile $profile
	}
    }
}



## Change password and group files
## DEPRECATED
Operation User::_update_ {} {
    # password::update ${_Self_} ../.. Name Password $Group
    
    return 0
}

## Generate a password
Operation User::password:generate ! {

    set password [ password::generate ]
    set Password [ Session::crypt $password ]
    layout::alert "Name\t:\t$Name\nPassword\t:\t$Password\nProfile\t:$Profile"
    data::record ${_Self_}    
    
    content::show ${_Self_}
}
