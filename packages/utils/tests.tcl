#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: tests.tcl
# 
## Generate tests from a test description language
##
## TODO: test this package !!
## TODO: a DTD for this language

package provide tests 1.0

namespace eval tests {

    variable N		10
    variable Args

    array set Args {
	tests {
	    n		10
	    reset	1
	    prefix	T
	}
	set {
	    name	""
	}
	value  {
	    type	 int
	    min		-1000
	    max	 	1000
	    name	""
	    format	%s
	}
	literal		{
	}
	repeat {
	    count	1
	}
	br {
	    count	1
	}
	sp {
	    count	1
	}
    }
}

## Process a test definition
proc tests::generate {dir def} {
    variable Dir $dir

    parse $def
}

## Parse a test definition
proc tests::parse {def} {
    set test ""

    while { [ regexp  {<(\w+)([^/>]*)(/?)>(.*)$} $def - com args empty def ] } {

	if { [ info command el_$comm ] == "" } {
	    error "invalid element {<code>$comm</code}>"
	}
	if { $empty == "" } {
	    if { [ llength [ info args el_$comm ] ] == 1 } {
		error "element {<code>$comm</code>} is empty"
	    } else {
		append test [ el_$comm $args  [ xml::container $comm def ] ]
	    }
	} else {
	    if { [ llength [ info args el_$comm ] ] == 2 } {
		append test [ el_$comm $args ] "" 
	    } else {
		append test [ el_$comm $args ] 
	    }
	}
    }
    return $test
}





#------------------------------------------------------------------------------
# procedures that define elements (all with prefix "el_")

## top element tests
proc tests::el_tests {list container} {
    variable Args
    variable Dir

    array set a $Args(tests)
    array set a [ xml::args $list ]

    if $a(reset) {
	# limpar tops os teste ja existentes    
	foreach d [ glob -nocomplain -types d $Dir/* ] {
	    file delete -force -- $d
	}
    }
    for { set i 0 } { $i < $a(n) } { incr i } {
	# generate os testes
	set test $Dir/$a(prefix)$i
	set tst [ data::new {$}test  Teste ]
	set ${tst}::input input
	data::record$test

	set fd [ open $test/inputw ]
	puts $fd [ parse $container ]
	catch { close $fd }
    }
}

## repetition of a block
proc tests::el_repeat {list container} {
    variable Args

    array set a $Args(repeat)
    array set a [ xml::args $list ]

    set r ""
    
    for { set i 0 } { $i < $a(count) } { incr i } {
	append r [ parse $container ]
    }
    return $r
}

## define a value
proc tests::el_set {list container} {
    variable Args

    array set a $Args(set)
    array set a [ xml::args $list ]

    namespace eval envir [ list set $a(name) $container ]

    return ""
}

## literal value
proc tests::el_literal {list container} {
   variable Args

    array set a $Args(literal)
    array set a [ xml::args $list ]

    return $container
}

## Line brake(s)
proc tests::el_br {list} {
    variable Args

    array set a $Args(br)
    array set a [ xml::args $list ]

    set b ""
    for { set i 0 } { $i < $a(count) } { incr i } {
	append b "\n"
    }
    return $b
}

## Space(s)
proc tests::el_sp {list} {
    variable Args

    array set a $Args(sp)
    array set a [ xml::args $list ]

    set b ""
    for { set i 0 } { $i < $a(count) } { incr i } {
	append b " "
    }
    return $b
}


## Generate value
proc tests::el_value {list} {
    variable Args

    array set a $Args(value)
    array set a [ xml::args $list ]

    switch $a(type) {
	int	{    set v [ expr int(($a(min)) + (rand() * (($a(max))-($a(min))))) ]	}
	float	{    set v [ expr     ($a(min)) + (rand() * (($a(max))-($a(min))))) ]	}
	default {
	    set r [ expr int(rand()*[ llength $a(type) ]) ]
	    set v [ lindex $a(type) $r ]

	}
    }

    namespace eval envir [ list set $a(name) $v ]

    return [ format $a(format) $v ]
}
