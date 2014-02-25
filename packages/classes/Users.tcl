#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Users.tcl
# 
## Set of Mooshak users (excluding teams): admin, judge, runner

package provide Users 1.0

package require data
package require User

Attributes Users {

    User dirs	User
    
}
