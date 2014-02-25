#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: classify.tcl
# 
## Commands used for generating cassification strings (ex: "First Place")
## Strings depend on the language hence the actual command for generating
## classifications must be requested to <code>classifier</code>, a sort of
## factory method

package provide classify 1.0

namespace eval classify {

    namespace export classifier
    namespace export classify_pt
    namespace export classify_en
}


## Factory returning procedure depending of current language
proc classify::classifier {} {
    
    if [ string equal [ lindex [ translate::langs ] 0 ] pt ] {
	set lang pt
    } else {
	set lang en
    }

    return classify::classify_$lang
}

## Generates a text classification in Portuguese for position (gender sensitive)
proc classify::classify_pt {pos {genero M}} {

    if { $pos == 0 } {
	 return "Menção Honrosa"
    } else {
	if [ string equal $genero F ] {
	    return "${pos}&#186; Classificada"
	} else {
	    return "${pos}&#186; Classificado"
	}
    }
}


## Generates a text classification in English for position
proc classify::classify_en {pos {genero M}} {

    if { $pos == 0 } {
	return "Honorable Mention"	
    } else {
	return [ format {%s place} [ string totitle [ in_full $pos ] ] ]
    }
}

## Writes ordinals in full (English)
proc classify::in_full {pos {genero M}} {

    if { $pos <= 20 } {
	switch $pos {
	    1 {  return "first"		}
	    2 {	 return "second"	}
	    3 {	 return "third"		}
	    4 {	 return "fourth"	}
	    5 {	 return "fifth"		}
	    6 {	 return "sixth"		}
	    7 {	 return "seventh"	}
	    8 {	 return "eighth"	}
	    9 {	 return "ninth"		}
	    10 { return "tenth"		}
	    11 { return "eleventh"	}
	    12 { return "twelfth"	}
	    13 { return "thirteenth"	}
	    14 { return "fourteenth"	}
	    15 { return "fifteenth"	}
	    16 { return "sixteenth"	}
	    17 { return "seventeenth"	}
	    18 { return "eighteenth"	}
	    19 { return "nineteenth"	}
	    20 { return "twentieth"	}
	}
    } elseif { $pos > 20 && $pos < 30 } {
	return [ format "twenty-%s" [ in_full [ expr $pos % 10 ] ] ]
    } elseif { $pos == 30 } {
	return "thirtieth"
    } elseif { $pos > 30 && $pos < 40 } {
	return [ format "thirty-%s" [ in_full [ expr $pos % 10 ] ] ]
    } elseif { $pos == 40 } {
	return "fortieth"
    } elseif { $pos > 40 && $pos < 50 } {
	return [ format "forty-%s" [ in_full [ expr $pos % 10 ] ] ]
    } elseif { $pos == 50 } {
	return "fiftieth"
    } elseif { $pos > 50 && $pos < 60 } {
	return [ format "fifty-%s" [ in_full [ expr $pos % 10 ] ] ]	
    } else {
	return "?"
    }
}

# debugging
proc classify::test_classify {} {
    for { set pos 0 } { $pos < 60 } { incr pos } {
	puts [ format {%2d %s} $pos [  classify::classify {$}pos ] ]
    }
}
