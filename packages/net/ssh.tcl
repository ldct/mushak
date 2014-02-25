#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: ssh.tcl
# 
## SSH related procedures

package provide ssh 1.0

namespace eval ssh {
    variable Dir	.ssh		;# ssh directory
    variable Config	config		;# ssh configuration file
    variable Key_fx	id_		;# key file prefix
    variable Pub	.pub		;# public key file extension
    variable Auth 	authorized_keys ;# autorized keys file
    variable Alg	rsa		;# public key algorithm
    variable Phrase	""		;# pass phrase 

    namespace eval ::utils {}	;# WHY ?!
    namespace import ::utils::*    

    namespace export fx_key		;# Name of key files
    namespace export with_key		;# Is there a file with key?
    namespace export create_key		;# Creates key file
    namespace export invalid_password	;# Cheks password
    namespace export read_authorized 	;# Reads key ring
    namespace export write_authorized	;# Writes key ring
    namespace export authorized 	;# Cheks if key is in key ring
    namespace export authorize		;# Add key to key ring
    namespace export unauthorized	;# Remove key from key ring
}

## Pathames of key related files: public and private keys, and keyring
proc ssh::fx_key {{type {}}} {
    variable Dir
    variable Key_fx
    variable Auth
    variable Alg
    variable Pub

    global DIR_BASE

    switch -regexp $type {
	aut 		{ return $DIR_BASE/$Dir/${Auth} }
    	pub 		{ return $DIR_BASE/$Dir/${Key_fx}${Alg}${Pub} }
	pri - default	{ return $DIR_BASE/$Dir/${Key_fx}${Alg} }
    }
}

## Is there a file with key?
proc ssh::with_key {} {

    return [ file readable [ fx_key ] ]
}

## Creates key file
proc ssh::create_key {} {
    variable Dir
    variable Config
    variable Alg
    variable Phrase

    file mkdir $Dir
    set fd [ open $Dir/$Config w ]
    puts $fd "StrictHostKeyChecking no"
    close $fd

    file attributes $Dir -permissions 0700
    exec ssh-keygen -q -t $Alg -f [ fx_key ] -N $Phrase
#    file attributes [ fx_key ] -permissions go-rwx
}

## Cheks password
proc ssh::invalid_key {key} {

    return [ expr ! [ regexp {^ssh-(rsa|dss)} $key ] ]
}

## Reads key ring
proc ssh::read_authorized {} {

    if [ file readable [ set fx [ fx_key aut ] ] ] {
	return [ file::read_in $fx ]
    } else {
	return ""
    }

}

## Writes key ring
proc ssh::write_authorized {keys_} {
    upvar $keys_ keys

    set path [ fx_key aut ]
    file mkdir [ file dirname $path ]
    set fd [ open $path w ]
    puts -nonewline $fd $keys
    close $fd

}

## Writes key ring: list of authorizations
proc ssh::key_ring {} {
    set l {}
    foreach lin [ split [ read_authorized ] \n ]  {
	if [ regexp {ssh-[^ ]* [^ ]* ([^ ]*)$} $lin - aut ] {
	    lappend l $aut
	}
    }
    return [ etc::unique $l ]
}

## Cheks if key is in key ring
proc ssh::authorized {keys_ password} {
    upvar $keys_ keys

    return [ expr [ string first $password $keys ] != -1 ]
}

## Add key to key ring
proc ssh::authorize {keys_ password} {
    upvar $keys_ keys

    append keys $password
}

# Remove key from key ring
proc ssh::unauthorized {keys_ password} {
    upvar $keys_ keys

    set n 0
    while { [ set p [ string first $password $keys ] ] > -1 } {
	incr n
	set keys [ string replace $keys $p \
			 [ expr $p + [ string length $password ] ] ]
    }

    return $n
}
