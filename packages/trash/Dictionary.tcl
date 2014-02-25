#
# Mooshak: managing  programming contests on the web		Abril 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Dictionary.tcl
# 
# Dicionario usado na traducao

package provide Dictionary 1.0

package require data

Attributes Dictionary {

    Partdirs	Parte
    
}

Operation Dictionary::agrega {} {

    # actualizar dicionario
    set fd [ open ${_Self_}/.dic w ]
    puts $fd "array set Dic {"
    foreach dir [ glob -nocomplain ${_Self_}/*/* ] {
	set pal [ date::open$dir ]
	
	set invalid 0
	foreach var {Palavra Traducao Troca} {
	    if [ info exists ${pal}::${var} ] {
		set $var [ set ${pal}::${var} ]
	    } else {
		set invalid 1
	    }
	}
	# o registo pode ainda não estar actualizado
	if $invalid continue

	switch $Troca  {
	    seguinte {
		set pre {\m(\w+)\M(\s+)}
		set Word ${pre}$Word
		set pos {\3\2}
		set Translation ${Traducao}${pos}
	    }
	    previous {
		puts {Troca anterior ainda não implementada}
	    }
	    
	}
	puts $fd [ format "{%-40s %s}" [ list $Word ] [ list  $Translation ] ]
    }

    puts $fd "\}"
    catch { close $fd }

    set language	[ file tail [ file::canonical_pathname ${_Self_} ] ]
    set formats	[ file::canonical_pathname ${_Self_}/../../formatos/${linguagem} ]

    if [ file exists $formats ] {
	file delete -force -- $formats
    }
}

