#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file:  Profile.tcl
# 
## User profile: authorization to execute commands given to a set of users
#
## 

package provide Profile 1.0

package require data

namespace eval Profile {
    set Screens { admin judge teacher team exam runner guest }
}

Attributes Profile [ list   						\
			 Screen     menu $Profile::Screens		\
			 Authorized list [ lsort [ execute::commands ] ]\
			]


