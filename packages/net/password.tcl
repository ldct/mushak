#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: password.tcl
# 
## Managing Apache password a group files (users and contestants)
##
## TODO: Use (also) LDAP for managing passwords. 

package provide password 1.0
namespace eval password {


    variable Group_file	.htgroup		;# group file
    variable Pass_file	.htpasswd		;# password file
    variable Pass_comm	htpasswd		;# password changing command
    variable Pass_flgs	-b			;# flags for previous command

    #variable Key_chars {[a-zA-Z0-9]}		;# chars in generated passords
    # avoid confusing chars O0 1l
    variable Key_chars {[a-km-zA-NP-Z02-9]}	;# chars in generated passords
    variable N_chars_in_key	6		;# number of char in passords

    global env					;# location of password command

    append env(PATH) :/usr/bin:/usr/sbin

}

## Recreate autentication files
## 	dir:    directory for files
## 	auths:  list of pairs name, password
proc password::recreate {dir auths {group team}} {
    variable Group_file
    variable Pass_file
    variable Pass_comm
    variable Pass_flgs

    set htpasswd $dir/$Pass_file
    set htgroup $dir/$Group_file


    # read in groups 
    if { [ file exists $htgroup ] } {
	foreach date [ split [ file::read_in $htgroup ] \n ] {
	    foreach {gr uts} [ split $date : ] {}
	    set in_group($gr) $uts
	}
    } 
    # forget all elements in this group
    set in_group($group) {}

    # process autentications and update passwords
    foreach {name password} $auths {
	regsub -all { } $name _ name
	lappend in_group($group) $name
	
	if { $name != "" && $password != "" } {
	    set flags $Pass_flgs
	    if { ! [ file exists $htpasswd ] } {
		lappend flags -c
	    }
	    catch { 
		eval exec $Pass_comm $flags $htpasswd $name [ list $password ] 
	    } msg
	    global env

	    execute::record_error $msg
	    #layout::alert $msg
	}
    }
    exec chmod a+r $htpasswd

    # write group file
    set fd [ open $htgroup w ]
    foreach gr [ array names in_group ] {
	puts $fd [ format {%s:%s} $gr $in_group($gr) ]
    }
    catch { close $fd }


    exec chmod a+r $htgroup
}


## Update autenticatio files for a given name and password
## 	base:    directorio relativo para fxs (ex: ../../..)
## 	name_:   name of variable with user name
## 	password_:  name of variable with password
proc password::update {dir base name_ password_ {group team}} {
    variable Group_file
    variable Pass_file
    variable Pass_comm
    variable Pass_flgs

    upvar $name_ name
    upvar $password_ password

    # group
    set file $dir/$base/$Group_file
    if { [ file exists $file ] } {
	foreach date [ split [ file::read_in $file ] \n ] {
	    foreach {gr uts} [ split $date : ] {}
	    set in_group($gr) $uts
	}
    } 

    if { ! [ info exists in_group($group) ] } {
	set in_group($group) {}
    }

    if { [ file exists $dir/$data::Data_file ] } {
	namespace eval old [ list source $dir/$data::Data_file ]

	# doesn't work well since file has already been changed
	if { 
	    [ info exists old::${name_} ] && 
	    [ set p [ lsearch $in_group($group) [ set old::${name_} ] ] ] > -1 
	} {
	    set in_group($group) [ lreplace $in_group($group) $p $p ]
	}
    }
    lappend in_group($group) $name
    set fd [ open $file w ]
    foreach gr [ array names in_group ] {
	puts $fd [ format {%s:%s} $gr $in_group($gr) ]
    }
    catch { close $fd }

    # passwords
    if { $name != "" && $password != "" } {
	set file $dir/$base/$Pass_file
	set flags $Pass_flgs
	if { ! [ file exists $file ] } {
	    lappend flags -c
	}
	catch { 
	    eval exec $Pass_comm $flags $file $name [ list $password ] 
	} msg
	execute::record_error $msg
	# layout::alert $msg
    }

}

## Generates a randon password 
proc password::generate {} {
    variable Key_chars
    variable N_chars_in_key

    set chars ""
    for { set i 0 } { $i < 128 } { incr i } {
	set c [ format %c $i ]
	if [ regexp $Key_chars $c ] {
	    append chars $c
	}
    }
    set l [ string length $chars ]
    set password ""
    for { set i 0 } { $i < $N_chars_in_key } { incr i } {
	append password [ string index $chars [ expr int(rand() * $l) ] ]
    }
    return $password
}

