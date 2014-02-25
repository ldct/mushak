#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: compare.tcl
# 
## Compares two strings showing the least number of differences. 
## For small outputs is used a special procedures that hilites diferences
## For long outputs is used diff.
##
## TODO: Make the output of diff show_diference 
##       similar to the output of show_diference


package provide compare 1.0

namespace eval compare {

    variable Count	   0		;# number of differences
    variable Limit     10000		;# maximum number de diferencas
    variable DIFF	/usr/bin/diff	;# Unix diff command

    namespace export normalize		;#
    namespace export show_differences	;# 
}


## Output normalization for presentation error: convert to lower case,
## replace white chars by single spaces and trim them.
proc compare::normalize {value} {
 
    set value [ string tolower $value ]
    regsub -all {(\s)+} $value { } value
    regsub -all {(\s)+$} $value {} value
    regsub -all {^(\s)+} $value {} value
    return $value
}


## HTML formatting of string differences
proc compare::show_differences {right wrong} {

    set difference ""

    set trl 0
    if { [ catch { 
	foreach {type chars pos} [ differences $right $wrong ] {
	    append difference [ string range $right $trl [ expr $pos - 1 ] ]
	    set trl [ expr $pos + [ string length $chars ] ]
	    switch $type {
		insert {
		    set rep "<U>$chars</U>"
		} 
		remove {
		    set rep "<S>$chars</S>"
		}
		default {
		    layout::alert "type: $type"
		}
	    }
	    append difference "<font color='red'>$rep</font>"
	}
	append difference [ string range $right $trl end ]
    } msg ] } {
	#execute::record_error $msg 
	set difference [ format {<i>%s</i>} \
			     [ translate::sentence "Incomparable" ] ]
    }

    return $difference
}

## computes list of differences between two strings
proc compare::differences {sa sb} {
    variable Count 0

    set la  [ string length $sa ]
    set lb  [ string length $sb ]

    # solution cannot be worst than inserting sa and removing sb
    set lim [ list insert $sa 0 remove $sb 0 ] 

    return [ differ $sa 0 $la $sb 0 $lb {} $lim ]
}

## Computes a list of differences between two strings from given positions 
## with a limit. A list of differences is of the form {type chars pos}
##	sa	string a	sb	string b	cur	current list
##	i	pos in $sa	j	pos in $sb	lim	limit solution
##	ls	length of $sa	lb	length of $sb
##
proc compare::differ {sa i la sb j lb cur lim} {
    variable Count
    variable Limit

    # trim: too many differences
    if { [ incr Count ] > $Limit } { return ... }
    
    # trim: over the best solution
    if { [ cmp $cur $lim ] > 0 } {  return ...  }

    if { $i == $la } {
	if { $j == $lb } {
	    return $cur
	} else {
	    # too many characters 
	    return [ remove $sa $i $la $sb $j $lb $cur $lim ]
	}
    } else {
	if { $j == $lb } {
	    # too few characters 
	    return [  insert $sa $i $la $sb $j $lb $cur $lim ]
	} else {	    

	    set differences 	{}
	    set commands	{}

	    set ca [ string index $sa $i ]
	    set cb [ string index $sb $j ]

	    # heuristics: choose modification commands depending on strings
	    if { [ string compare $ca $cb ] == 0 } { lappend commands equal   }
	    if { [ string first $cb [ string range $sa [ expr $i+1 ] end ] ] > -1 } 	{ lappend commands insert }
	    if { [ string first $ca [ string range $sb [ expr $j+1 ] end ] ] > -1 } 	{ lappend commands remove }
	    # at least a modification (insert or remove)
	    if { $commands == {} } { lappend commands insert }
	    # process commands and choose best result (limit)
	    foreach command $commands {
		set diff [ $command $sa $i $la $sb $j $lb $cur $lim ]
		lappend differences $diff
		if { [ cmp $diff $lim ] < 0 } { set lim $diff }
	    }
	    return $lim
	}
    }
}

## continue searching differences without making changes
proc compare::equal {sa i la sb j lb cur lim} {    
    return [ differ $sa [ expr $i + 1 ] $la $sb [ expr $j + 1 ] $lb $cur $lim ]
}

## insert a character and continue searching for differences
proc compare::insert {sa i la sb j lb cur lim} {    
    set cur [ compact $cur insert [ string index $sa $i ] $i ] 
    return [ differ $sa [ expr $i + 1 ] $la $sb $j $lb $cur $lim ] 
}
 
## remove a character and continue searching for differences
proc compare::remove {sa i la sb j lb cur lim} {
    set cur [ compact $cur remove [ string index $sb $j ] $j ]
    return [ differ $sa $i $la $sb [ expr $j + 1 ] $lb  $cur $lim ]
}

## compact modifications in current list
proc compare::compact {cur type char pos} {

    set cpos  [ lindex $cur end ]
    set chars [ lindex $cur end-1 ]

    if { 
	[ string compare [ lindex $cur end-2 ] $type ] == 0 &&
	$cpos + [ string length $chars ] ==  $pos
    } {

	set chars $chars$char

	return [ concat [ lrange $cur 0 end-3 ] [ list $type $chars $cpos ] ]
    } else {
	return [ concat $cur [ list $type $char $pos ] ] 
    }
}

## Compares two lists with differences; the smallest has less differences 
## and less types of differences. Trimmed lists (ending with ...) are greater 
## than any non trimmed list but equal to each other.
proc compare::cmp {l1 l2} {

    if { [ string compare [ lindex $l1 end ] ... ] == 0 }  {
	if { [ string compare [ lindex $l2 end ] ... ] == 0 }  {
	    set res 0
	} else {
	    set res 1
	}
    } else {
	if { [ string compare [ lindex $l2 end ] ... ] == 0 }  {
	    set res -1 
	} else {
	    
	    foreach l {l1 l2} {
		set n($l) 0
		set d($l) 0
		foreach {type chars -} [ set $l ] {
		    incr n($l)
		    incr d($l) [ string length $chars ]
		}
	    }    
	
	    if { $d(l1) == $d(l2) } {
		set res [ expr $n(l1) - $n(l2) ]
	    } else {	
		set res [ expr $d(l1) - $d(l2) ]
	    }

	}
    }
    return $res
}


proc example {n} {
    set key_chars {[ a-zA-Z0-9]}


    set chars ""
    for { set i 0 } { $i < 128 } { incr i } {
	set c [ format %c $i ]
	if [ regexp $key_chars $c ] {
	    append chars $c
	}
    }
    set l [ string length $chars ]
    set string ""
    for { set i 0 } { $i < $n } { incr i } {
	append string [ string index $chars [ expr int(rand() * $l) ] ]
    }
    return $string
}

# unitary tests
proc test {} {

    set n 1
    while 1 {
	set right	[ example $n ]
	set wrong	[ example $n ]
	puts $n
	puts $right
	puts $wrong
	puts [ compare::differences $right $wrong ]
	puts -----------------------------------------------
	incr n 10
    }
}

## Compare differences using unix diff
proc compare::show_differences2 {right wrong} {
    variable ::file::TMP
   
    foreach var { right wrong } {
	set fx($var) $TMP/$var[pid]
	set fd [ open $fx($var)  w ]
	puts $fd [ set $var ]
	catch { close $fd }
    }    

    set diffs [ diff $fx(right) $fx(wrong) ]

    file delete -force -- $fx(right) $fx(wrong)

    regsub {child process exited abnormally$} $diffs {} diffs
    return $diffs
}

## Use unix diff to compare two files
proc compare::diff {fxa fxb} {
    variable DIFF
    global errorInfo
    global errorCode

    set ec $errorCode
    if { [ string compare $errorCode NONE ] == 0 } {
	# tclsh 8.6 may have errorInfo undefined if error code is NONE
	set ei ""	
    } else {
	set ei $errorInfo
    }

    catch {  exec $DIFF $fxa $fxb } diffs

    set errorInfo $ei
    set errorCode $ec

    return $diffs
}
