#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Groups.tcl
# 
## Namages an LDAP configuration and connections (authentication) to that server
##

package provide LDAP 1.0

package require data

namespace eval LDAP {

    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Command		"Command for executing LDAP queries (e.g. /usr/bin/ldapsearch)"
	Host		"Host name (or IP) of the LDAP server"
	Bind_DN		"Distinguished Name to bind LDAP directory"
	Base_DN		"Starting point for the search instead of the default"
	Login_Attribute "LDAP attribute recording login id (default: uid)"
    }

}

Attributes LDAP {
    Command		text	{}
    Host		text	{}
    Bind_DN		text	{}
    Base_DN		text	{}
    Login_Attribute	text	{}
}

Operation LDAP::_update_ {} {

    if { [ info exists Command ] && $Command != "" } {
	if { ! [ file executable $Command ] } {
	    layout::alert "Invalid command $Command"
	} 
    }
    
    return 0
}


## Authenticate user in this LDAP server
## Returns hash if user is authenticated and {} otherwise
Operation LDAP::authenticate {user password} {

    if { [ info exists Login_Attribute ] && $Login_Attribute != "" } {
	if { [ catch  {
	    set uid [ ${_Self_} search_host $Login_Attribute $user uid ]
	} ]  } {
	    # just in case
	    set uid nobody
	}
    } else {
	set uid $user
    }

    if { [ catch  {
	set hash [ ${_Self_} search_host uid $uid userPassword $password ]
    } ]  } {
	set hash ""
    }
    
    return $hash
}


## Tests if connection to LDAP server is up and running
## (searches nobody with password "?" and checks "ldap_bind:" in error message)
Operation LDAP::ldap:test ! {

    catch { ${_Self_} search_host uid nobody userPassword ? } error_message

    if [ regexp "ldap_bind:" $error_message ] {
	set message  [ translate::sentence "LDAP server is reachable" ]
    } else {
	
	set message [ format "%s: %s" 					\
			  [ translate::sentence 			\
				"Unexpected output from LDAP server" ] 	\
			  $error_message ]
    }
    layout::alert $message
    
    content::show ${_Self_}

}

# Searches LDAP host for entry with attr=value to return request
# (optionally pass password for authentication)
Operation LDAP::search_host {attr value request {password ""}} {

    set args {}
    lappend args 	[ format {%s}		$Command	]
    lappend args 	[ format {-LLL -x}			]
    if { [ string equal $attr "uid" ] } {
	lappend args 	[ format {-D uid=%s,%s} $value $Bind_DN	]
    }
    lappend args 	[ format {-b %s}	$Base_DN	]
    lappend args 	[ format {-h %s} 	$Host		]
    if { ! [ string equal $password "" ] } {
	lappend args 	[ format {-w "%s"}	$password	]
    }
    lappend args 	[ format {%s=%s}  	$attr $value	]
    lappend args 	[ format {%s}		$request	]
    set command_line [ join $args " " ]

    set output ""
    set fd [ ::open "| $command_line " r ]    
 
    gets $fd dn_line
    gets $fd answer_line
    ::close $fd 

    foreach { - answer} $answer_line {}
    return $answer
}
