#-*-Mode: TCL; iso-accents-mode: t;-*-	
#
# This package extends the safety mechanims of safeTk by
# 	preventing denial of service atacks:
#		- for and while have a maximum number of iterations
#		- pack, grid and place cannot be mixed in the same level
#
#							zp@ncc.up.pt   1998

package provide saferTk 1.0

namespace eval saferTk {
    namespace export inicia avalia ajusta
    
    
    variable MAX_ITERA	1000	;# Número máximo de iterações num cíclos
    variable Buffer 		;# buffer de IO de canais do 'puts'
    variable Prompt "% "	;# Prompt par comandos interactivos
}

# avalia "$prog" num interpretador "$base" com a janela de topo ".$base"
proc saferTk::avalia {base prog {px +100} {py -100}} {

    destroy  .$base
    toplevel .$base
    wm geometry .$base 100x100${px}${py}
    bind $base <Enter> [ list focus -force \[ focus -lastfor $base \] ]

    catch { ::safe::interpDelete $base }
    ::safe::interpCreate $base

    ::safe::loadTk $base
    #::safe::loadTk $base -use [ winfo id .$base ] 

    $base alias puts ::saferTk::echo
    #interp eval $base { proc avalia com { return [ uplevel $com ] } }
    #$base hide avalia
    #$base hide for
    #$base alias for ::saferTk::para $base
    #$base hide while
    #$base alias while ::saferTk::enquanto $base
    #foreach tipo {place pack grid} {
    	#$base hide $tipo
	#$base alias $tipo ::saferTk::dispoem $base $tipo
    #}

    return [ interp eval $base $prog ]
    
}

# versão segura dos comandos de colocação de 'widgets' no interface
# evita que num mesmo nível da árvore de interface sejam usados dois
# comandos deste tipo, o que faz abortar a wish
proc saferTk::dispoem args {
    set base [ lindex $args 0 ]
    set tipo [ lindex $args 1 ]
    set args [ lrange $args 2 end ]
    foreach arg $args {
	# se é uma janela
	if { [ regexp {^\.[a-z0-9][\.a-zA-Z0-9]*$} $arg ] } {
	    if { [ set pai [ file root $arg ] ] == "" } { set pai . }
	    foreach t {pack place grid} {
		if { [ string compare $t $tipo ] == 0 } continue
		set filhos [ interp invokehidden $base $t slaves $pai ]
		if { $filhos != "" } {
		    echo "$tipo: $filhos foram dispostos com $t\n"
		    return 
		}
	    }
	}
    }
    eval interp invokehidden $base $tipo $args
}

# versão segura do comando 'for' com limite do número de iterações
proc saferTk::para args {
    variable MAX_ITERA

    switch [ llength $args ] 5 {

	foreach {base inicio teste limite ciclo} $args {}
	set n $MAX_ITERA

	for { interp eval $base $inicio } \
		{ [interp eval $base [list expr $teste] ]  != 0 }\
		{ interp eval $base $limite } {
	    
	    set com {set s [ catch CICLO e ] ; subst " $s [ list $e ] " }
	    regsub CICLO $com [ list $ciclo ] com
	    foreach {code string} [ interp eval $base $com ] {}

	    switch $code  {
		0 {}
		1 - 2 { return -code $code $string }
		3 { break }
		4 { continue }
	    }
	    if { [ incr n -1 ] == 0 } {
		error "Atingido o limite de $MAX_ITERA	iterações em \n\
			for [ list $inicio ]\
			[ list $teste  ]\
			[ list $limite ]\
			[ list $ciclo  ]\n" "info" 99
		break
	    }
	}
    } default {
	error "wrong # args: should be \"for start test next command\""
    }
}

# versão segura do while
proc saferTk::enquanto args {
    variable MAX_ITERA

    switch [ llength $args ] 3 {
	set i -1
	foreach var {base teste ciclo} {
	    set $var [ lindex $args [ incr i ] ]
	}
	set n $MAX_ITERA

	while { [interp eval $base [list expr $teste]] != 0 } {
	    	    
	    set com {set s [ catch CICLO e ] ; subst " $s [ list $e ] " }
	    regsub CICLO $com [ list $ciclo ] com
	    foreach {code string} [ interp eval $base $com ] {}

	    switch $code  {
		0 {}
		1 - 2 { return -code $code $string }
		3 { break }
		4 { continue }
	    }
	    
	    if { [ incr n -1 ] == 0 } {
		error "Atingido o limite de $MAX_ITERA	iterações em \n\
			while [ list $teste ] [ list $ciclo  ]\n"
		break
	    }
	}
    } default {
	error "wrong # args: should be \"while test command\""
    }
}



# processa os args como o puts mas guarda os carcteres em $buffer($canal)
# há um alias nos interp c/ safetk ligando o puts a esta proc
proc saferTk::echo args {
    variable Buffer

    switch -- [ lindex $args 0 ] -nonewline {
	set eol ""
	set args [ lrange $args 1 end ]
    } default {
	set eol \n
    }
    
    switch [ llength $args ] 0 {
	set texto {wrong # args: should be \
		"puts ?-nonewline? ?channelId? string"}
    } 1 {
	set canal stdout
	set texto [ lindex $args 0 ]
    } 2 {
	set canal [ lindex $args 0 ]
	set texto [ lindex $args 1 ]
    }
    append Buffer($canal) $texto$eol
}




# calcula o tamanho máximo de uma janela de toplevel que serve de base
# a um interpretador e (re)ajunta as suas dimensões como seria feito normal/
proc saferTk::ajusta {base {px +100} {py +100}} {

    set w 100
    set h 0

    interp eval $base [ list update idletasks ]

    foreach win [ interp eval $base [ list winfo children . ] ] {
	foreach var { x y width height } {
	    set $var [ interp eval $base [ list winfo $var  $win ] ]
	}
	
	set xm [ expr $x + $width ]
	set ym [ expr $y + $height ]

	if { $xm > $w } { set w $xm }
	if { $ym > $h } { set h $ym }
    }
    wm geometry .$base ${w}x$h${px}${py}
    wm minsize .$base ${w} $h
}

# avlia um linha de comandos no interpretador dado
proc saferTk::interactive_shell {base command_line} {
    variable Prompt
    if [ catch { set output [ interp eval $base $command_line ] } erro ] {
	append output \n$erro
    }
    return $output\n$Prompt
}