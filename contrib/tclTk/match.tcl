#-*-Mode: TCL; iso-accents-mode: t;-*-	
#
# Comparison of tclTk program based on matching side-effects
#							zp@ncc.up.pt   1998

package provide match 1.0

namespace eval match {
    namespace export verifica

    # Atributos relacionados com 
    variable AvoidArg { 
	-textvariable 
	-command 
	-variable
	-xscrollcommand 
	-yscrollcommand 
	-offset
	-validatecommand
    }
}

# verifica o programa correndo $teste depois de substituir os nomes 
# dos objectos do exemplo pelos correspondentes da resoluçao
proc match::verifica {exemplo resolucao teste s} {
    upvar $s sub
    
    foreach var [ array names sub ] {
	#puts $var->$sub($var)
	interp eval $resolucao \
	    [ list namespace eval Teste \
		  [ list proc $var args [ format {eval ::%s $args} $sub($var) ] ] ]
    }

    interp eval $resolucao { 
	proc bgerror message {
	    global errorInfo errorCode
	    puts stderr "Erro num comando invocado pelo interface: $message"
	    #puts stdout $errorInfo
	}
    }
 
    if { [ catch {
 	set res [ interp eval $resolucao [ list namespace eval Teste $teste  ] ]
     } erro ] } {
	 set res "Erro na avaliação dos testes: $erro"
     } 

    return $res
}




# unifica as janelas . dos interpretadores 'a' e 'b'
# sendo 's' o nome de um array que transforma os objectos
# (a menos de frames) de 'a' em janelas de 'b'
proc match::unifica {a b s} {
    upvar $s sub
    variable AvoidArg

    interp eval $a {update}
    interp eval $b {update}

    catch { unset sub }

    filhos $a pa
    filhos $b pb

    set mensagem {}

    if { [ llength [ array names pa ] ] != [ llength [ array names pb ] ] } {
	catch { unset sub }
	lappend mensagem \
		"Deveriam existir [ llength [ array names pa ] ] objectos\
		visiveis (i.e. excluindo 'frames') colocados no interface"
    } else {
	foreach wa [ array names pa ] {
	    
	    # calcula o objecto mais proximo na resolucao
	    set min 100000
	    set wb {}
	    foreach w [ array names pb ] {
		set xa [ lindex $pa($wa) 0 ]
		set ya [ lindex $pa($wa) 1 ]
		set xb [ lindex $pb($w) 0 ]
		set yb [ lindex $pb($w) 1 ]
		set dd [ expr abs($xa-$xb) + abs($ya-$yb) ]

		if { $dd < $min } {
		    set min $dd
		    set wb $w
		}
	    }
#	    set f {%5s %5s %5s %9s   %5s %5s %5s %9s}	    
#	    eval puts \[ format \{$f\} $wa $pa($wa) $wb $pb($wb) \]

	    if { [ lindex $pa($wa) 2 ] == [ lindex $pb($wb) 2 ] } {
		# set loa [ lsort [ interp eval $a [ list $wa configure ] ] ]
		# set lob [ lsort [ interp eval $b [ list $wb configure ] ] ]
		set j -1		
		set sub($wa) $wb
		
		foreach arg [ interp eval $a [ list $wa configure ] ] {
		    foreach {opt - - init sol} $arg {}
		    if { [ lsearch $AvoidArg $opt ] > -1 } continue
		    if { [ string compare $init $sol ] != 0 } {
			set arg [interp eval $b [ list $wb configure $opt ] ]
			foreach {- - - - ans} $arg {}
			# puts stderr "$opt $init $sol $ans"
			if { [ string compare $sol $ans ] != 0 } {
			    lappend mensagem \
				    "Opcção $opt de $wb com valor errado '$ans'"
			}
		    }
		}

	    } else {
		catch { unset sub }
		lappend mensagem \
			"Na posição do objecto $wb devia \
			existir um objecto da classe '[ lindex $pa($wa) 2 ]'"
	    }
	}
    }
    return $mensagem
}

# gera um array com posicão (x,y) e classe
# dos objectos a unificar (exclui as frames por serem usadas no posicionamento)
proc match::filhos {intp p {obj .} {x 0} {y 0} {n 0}} {
    incr n
    upvar $n $p pos

    # seleciona os filhos que tenham sido posiconados na janela
    set children ""
    foreach posiciona { pack grid place } {

	append children [ interp eval $intp [ list $posiciona slaves $obj ] ]
	
	# DEPRECADO
	# usa a versão escondida do posicionador porque as expostas
	# foram reescritas devido ás incompatibilidades entre eles
	#append children [ interp invokehidden $intp  $posiciona slaves $obj ]
    }

    foreach c $children {
	set cl [ interp eval $intp [ list winfo class $c ] ]
	set xc [ expr $x + [ interp eval $intp [ list winfo x $c ] ] ]
	set yc [ expr $y + [ interp eval $intp [ list winfo y $c ] ] ]
	switch $cl {
	    Frame {
		filhos $intp $p $c $xc $yc $n
	    } 
	    default {
		set w  [ interp eval $intp [ list winfo width $c ] ]
		set h  [ interp eval $intp [ list winfo height $c ] ]
		set xm  [ expr $xc + $w/2 ]
		set ym  [ expr $yc + $h/2 ]
		set pos($c) [ list $xm $ym $cl ]
	    }
	}

    }
}
