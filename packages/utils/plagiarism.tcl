#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: plagiarism.tcl
# 
## File utilities

package provide plagiarism 1.0

namespace eval plagiarism {
    variable Suffix	".frn.tcl"	;# Suffix of frequency files    
    variable Threshold	10
}

proc plagiarism::compare_files {pattern} {
    variable Threshold

    word_frequency $pattern

    set filenames	[ glob -nocomplain $pattern ]
    set nfiles		[ llength $filenames ]

    for { set a 0 } { $a < $nfiles } { incr a } {
	for { set b  [ expr $a+1 ] } { $b < $nfiles } { incr b } {
	    set file_a [ lindex $filenames $a ]
	    set file_b [ lindex $filenames $b ]

	    set difference [ compare_two_files $file_a $file_b ]

	    if { $difference < $Threshold } {
		puts [ format {%4d: %40s %40s} $difference $file_a $file_b ]
	    }	    
	}
    }
}

proc plagiarism::compare_two_files {a b} {
    variable Suffix

    foreach {id filename} [ a $a b $b ] {

	namespace eval $id { array unset count }
	namespace eval $id [ list source ${filename}${Suffix} ]
	
	set array [ format {::plagiarism::%s::count} $id ]
	set command [ format {::plagiarism::compare %s} $array ]
	
	set words($id) [ lsort -command $command [ arrau names $array ] ]

	set nwords($id) [ llength $words($id) ]
    }

    map_frequencies ::plagiarism::a::count ::plagiarism::b::count map
    
    set diff 0
    foreach word [ array names map ] {
	set ca $::plagiarism::a::count($word)
	set cb $::plagiarism::b::count($map($word))
    } {	    
	set diff [ expr ($ca - $cb) * $Count($word) ]	    
    }

}

## Creates a mapping between words frequencies 
proc plagiarism::map_frequencies {ca_ cb_ map_} {
    variable Count
    upvar $ca_ ca
    upvar $cb_ cb
    upvar $map_ map

    

} 

proc plagiarism::word_frequency {pattern} {
    variable Suffix
    variable Count
    variable Occurs

    array unset Count
    foreach filename [ glob -nocomplain ${pattern} ] {

	if { ! [ file readable [ set frequency $filename${Suffix} ] ] } {
	    word_frequency_in_file $filename
	}	

	namespace eval file { array unset count }    
	namespace eval file [ list source $frequency ]
	foreach word [ array names file::count ] {
	    if [ file exists count($word) ] {
		incr Count($word) $file::count($word)
	    } else {
		set Count($word) $file::count($word)
	    }
	    
	    if [ info exists occurs($word) ] {
		incr Occurs($word)
	    } else {
		set Occurs($word) 1
	    }
	}
    }
}

proc plagiarism::word_frequency_in_file {filename} {
    variable Suffix
    variable count 

    foreach word [ words_from_file $filename ] {
	if [ info exists count($word) ] {
	    incr count($word)
	} else {
	    set count($word) 1
	}
    }

    set fd [ open "${filename}${Sufix}" w ]
    foreach word [ lsort -command {plagiarism::compare ::plagiarism::count} \
		       [ array names count ] ] {
	puts $fd [ format "set count(%s) %d" $word $count($word) ]
    }
    catch { close $fd }
}

## Returns a lists of words from file, removing language comments 
## and characters that don't appear in words
proc plagiarism::words_from_file {filename} {


    set data [ file::read_in $filename ]

    # remove comments (depends on Language)

    regsub -all {[^\w\d\s]} $data { } data

    return $data
}

## Compare array buckets
proc plagiarism::compare {array a b} {
    
    return [ expr [ set ${array}($a) ] < [ set ${array}($b) ] ]
}
