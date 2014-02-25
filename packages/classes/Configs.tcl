# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Configs.tcl
##
##
## Toplevel directory of Mooshak configurations
##


package provide Configs 1.0

package require data

namespace eval Configs {

    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content
    
    array set Tip {
	checks		"Testing current configuration"
	network		"Definition of network of Mooshak servers"
	users		"Generic users"
	profiles	"Users+ profiles"
	sessions	"Users' sessions"

	flags		"Nations (or other) flags used in listings"
    }
}

Attributes Configs {
    checks	dir	Checks
    network	dir	Network
    profiles	dir	Profiles
    sessions	dir	Sessions
    users	dir	Users
    flags	dir	Flags
    ldap	dir	LDAPs
}
