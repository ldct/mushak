#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: etc.tcl
# 
## Utilities

package provide etc 1.0

namespace eval etc {
    variable Time_ended

    namespace export accumulate		;## Accumulate unique values in list
    namespace export increment		;## Increments/defines a variavel 
    namespace export unique    		;## Returns unique elements of list
    namespace export acronym		;## Returns an acronym of sentence
    namespace export whoami		;## Returns server email-like address
    namespace export common_prefix	;## Returns longest common prefix of two strings
    namespace export common_sufix	;## Returns longest common sufixfix of two strings
    namespace export count_matches 	;## count matches of pattern in list
    namespace export shuffle	 	;## shuffle a list

}


## Accumulate unique values in the given list
proc etc::accumulate {list_ value} {
    upvar $list_ list

    if { ! [ info exists list ] || [ lsearch $list $value ] == -1 } { 
	lappend list $value 
    }    
}


## Returns the given list with duplicated elements removed
proc etc::unique {l} {

    set n {}
    foreach e $l {
	if { [ lsearch $n $e ] == -1 } {
	    lappend n $e
	}
    }
    return $n
}


## Increments a variable, inicializing it if needed
proc etc::increment {var_} {
    upvar $var_ var

    if [ info exists var ] {
	incr var
    } else {
	set var 1
    }
}

## Returns an acronym given a compound text using first letters
proc etc::acronym {text} {

    regsub -all {ÁÀÃÂ}	$text A text    
    regsub -all {ÉÈÊ}	$text E text    
    regsub -all {ÍÌÎ}	$text I text    
    regsub -all {ÓÒÕÔ}	$text O text    
    regsub -all {ÚÙÛ}	$text U text    
    regsub -all {Ç}	$text C text    
    regsub -all {Ñ}	$text N text    
    regsub -all {'-/:}	$text { } text
    regsub -all {[^ a-zA-Z0-9]} $text {} text
    regsub -all {  } $text { } text
    regsub -all { [a-zA-Z][a-zA-Z]? } $text { } text
    if { [ llength $text ] == 1 } {
	return [ file::valid_dir_name $text ]
    } else {
	set acronym {}
	foreach word $text {
	    append acronym [ string index $word 0 ]
	}
	
	return [ string toupper $acronym ]
    }
}

## returns longest common prefix of two strings
proc etc::common_prefix {a b} {

    set p ""
    set la [ string length $a ]
    set lb [ string length $b ]
    set l  [ expr $la < $lb?$la:$lb ]  
    for { set i 0 } { $i < $l } { incr i } {
	if { [ string equal [ string index $a $i ] [ string index $b $i ] ] } {
	    append p [ string index $a $i ]
	} else {
	    break
	}
    }
    return $p
}

## returns longest common sufix of two strings
proc etc::common_sufix {a b} {

    set p ""
    set la [ string length $a ]
    set lb [ string length $b ]
    set l  [ expr $la < $lb?$la:$lb ]  
    for { set i 0 } { $i < $l } { incr i } {
	set ca [ string index $a [ expr $la - $i ] ]
	set cb [ string index $b [ expr $lb - $i ] ]
	if { [ string equal $ca $cb ] } {
	    set p $ca$p
	} else {
	    break
	}
    }
    return $p
}

## count number of matches of pattern in list
proc etc::count_matches {l p} {

    set c 0
    set k 0
    while { [ set d [ lsearch [ lrange $l $k end ] $p ] ] > -1 } {
	incr k $d
	incr k
	incr c
    }
    return $c
}



## DEPRECATED
## Not a philosophical question, returns server email-like address
proc etc::whoami {} {
    global URL_BASE env

    if [ catch {set user $env(USER)} ] 	{ set user mooshak? }
    if [ catch {set host [ exec localhost ] } ] 	{ set host localhost? }
    regexp  {^http://([^/]+)/~(.*)$} $URL_BASE - host user

    return $user@$host
}

## Inverts the order of the elements of list given as input
## (without flattening it) e.g: {a {b c} {d e f}} -> {{d e f} {b c} a}
proc etc::invert { list } { 

    if { $list == {} } {
	return $list
    } else {

	set head [ lindex $list 0 ]
	set rest [ lrange $list 1 end ]

	set invert [ invert $rest ]
	lappend invert $head 
    }

    return $invert
}

## Shuffles elements of the list given as argument
proc etc::shuffle { list } {

    return  [ lsort -command ::etc::random $list ]
}

proc etc::random {a b} {
    return [ expr int(rand()*11)-5 ]
}
