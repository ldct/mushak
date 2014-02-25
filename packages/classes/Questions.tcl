#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Questions.tcl
# 
## Set of team question to human judges during a contests

package provide Questions 1.0

package require Question
package require data

namespace eval Questions {
    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Active		"Accept questions in the teams interface"
	Forward		"Forward questions to the contest's email address"
    }
}

#-----------------------------------------------------------------------------
#     Class definition


Attributes Questions {
    Active	menu	{ yes no }
    Forward	menu	{ yes no }
    Question	dirs	Question
}

    
## Check if directory is empty.
Operation Questions::check {} {
    check::dir_start 0
    check::dir_empty
    check::dir_end 0

}

## Is asking questions active (teams can ask questions)? Defaults to yes
Operation Questions::active {} {
    if { [ info exists Active ] && [ string equal $Active no ] } {
	return 0
    } else {
	return 1
    }
}

## Should questions be forward to contest's email address?
Operation Questions::forward {} {
    if { [ info exists Forward ] && [ string equal $Active yes ] } {
	return 1
    } else {
	return 0
    }
}



## Cleans directory.
Operation Questions::prepare {} {
    check::clear 
}

## questions listing.
Operation Questions::questions {{profile admin}} {

    set message ""
    set terms [ cgi::field terms "" ]

    listing::header message terms

    set fields	[ listing::define_vars ]
    set problem [ cgi::field problem "" ]
    set team	[ contest::team ]

    set questions [ listing::restrict ${_Self_} ] 
    set questions [ lsort -command \
			[ list listing::cmp \
			      [ list _${problem}_ _${team}\$ ] ] $questions ]
    set all_subs [ lsort -decreasing [ listing::unrestrict ${_Self_} ] ]
    set n_subs   [ llength $all_subs ]

    set contest [ contest::active_path ]
    data::open $contest

    set blackout 0 ; # don't hide listings during blackouts
    if { [ set limit [ $contest hide_listings message $profile $blackout ] \
	      ] > -1 } {
	set questions [ listing::older_submissions $questions $limit ]
    }

    if { ! [ string equal [ string trim $terms ] "" ] } { 
	set questions [ ${_Self_} filter $questions $terms ]
    }

    listing::part questions pages last n

    foreach sub $questions {
	if [ catch {
	    set m [ expr $n_subs - [ lsearch $all_subs $sub ] ]
	    data::open $sub
	    $sub listing_line $m $n $profile
	} msg ] {
	    incr n
	    # puts <pre>$msg</pre> ;# debugging
	    # DONT SHOW CORRUPTED LINES
	    #set m $n
	    #layout::toggle_color m color
	    #template::write empty
	}
	incr n -1
    }

    listing::footer [ incr n ] $pages $questions 
}


## Filter selected question according to search term
Operation Questions::filter {questions terms} {
    variable Filter


    array set Filter {}
    foreach question $questions {
	set qd [ data::open $question ]

	variable ${qd}::Subject
	variable ${qd}::Question
	variable ${qd}::Answer
	
	foreach term $terms {
	    set pattern [ format {*%s* } $term ]
	    
	    foreach {data weight} [ list $Subject 3 $Question 2 $Answer 1 ] {

		if [ string match -nocase $pattern $data ] {
		    if [ info exists Filter($question) ] {
			incr Filter($question) $weight
		    } else {
			set Filter($question) $weight
		    }
		}
	    }
	}
    }

    return [ lsort -command ::Questions::cmp_filter [ array names Filter ] ]
}

proc Questions::cmp_filter {a b} {
    variable Filter

    return [ expr $Filter($a) < $Filter($a) ]
}