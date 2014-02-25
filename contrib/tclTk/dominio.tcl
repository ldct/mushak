#-*-Mode: TCL; iso-accents-mode: t;-*-	
#
# Procedimentos dependentes do domínio de resolução: tcl/tk
#						{zp,nam}@ncc.up.pt   1998
#						
#-


package provide dominio 1.0

package require saferTk

namespace eval dominio {
    namespace export iniciar
    namespace export enunciar
    namespace export executar
    namespace export resolver
    namespace export terminar
}

proc dominio::iniciar {output} {
    ::saferTk::inicia $output
}

proc dominio::executar {exemplo prog} {
    ::saferTk::avalia $exemplo $prog -100 +100
    ::saferTk::ajusta $exemplo -100 +100
    return 1	;# usar a exemplificação
}

proc dominio::enunciar {exemplo} {
    return [ interp eval $exemplo Enuncia ]
}

proc dominio::resolver {resolve exemplo} {

    ::interface::limpar_output

    set classe 0
    set estado Erros
    set obs ""

    # carrega o programa e testa erros sintáticos
    set prog [ .resolucao.texto get 1.0 end ]

    if { [ catch { set output [ \
	    ::saferTk::avalia $resolve $prog -100 -100 ] } erros ] } {
	set classe 10
	append obs $erros\n
	# já nem tenta fazer mais nada
	# return
    } else {
	::interface::output $output\n
    }    
    # actualiza o programa
    catch { interp eval $resolve [ list update idletasks ] } erros
    append obs $erros\n
    ::saferTk::ajusta $resolve -100 -100


    # compara os interfaces do exemplo e da resolução (retorna substituições)
    ::interface::exemplifica    
    if { [ set erros [ unifica $exemplo $resolve sub ] ] != "" } {

	switch -regexp -- $erros {
	    "^Deveriam existir"		{ set classe 10  }
	    "^Erro no interface"	{ set classe 20  }
	    "^Opção"		{ set classe 22  }
	}
	append obs $erros\n

    } else {
	# verifica a funcionalidade do programa
	set result [ verifica $exemplo $resolve sub ]
	set cota [interp eval $exemplo {set COTACAO(unifica)}] 
	set classe	[ expr int($cota + [ lindex $result 0 ]) ]
	append obs	[ join [ lindex $result 1 ] \n ]
	if { $classe == 100 } {	
	    set estado Concluido
	    set obs "Exercício resolvido\n"
	    
	    set falta $cronometro::Tempo(.resolucao.crono)
	    set dura [ expr [ ::dados::determina_tempo ] - $falta ]
	    ::dados::log Tempo "$dura minutos"
	    .resolucao.botoes.ok configure -state normal
	    
	} 
    }

    ::interface::output $obs $estado
    ::dados::regista $prog $classe $obs 
}

# verifica o programa correndo 'Teste' depois de substituir os nomes 
# dos objectos do exemplo pelos correspondentes da resoluçao
proc dominio::verifica {exemplo resolucao s} {
    upvar $s sub

    set teste [ interp eval $exemplo {info body Teste} ]
    set delim {^|$|[^\.a-zA-Z0-9_=]}
    
    foreach var [ array names sub ] {
	regsub -all {\.} $var {\.} nome
	regsub -all ($delim)($nome)($delim) $teste \\1=\\2=\\3 teste
    }
    foreach var [ array names sub ] {
	regsub -all {\.} $var {\.} nome
	regsub -all =$nome= $teste $sub($var) teste
    }
    interp eval $resolucao [ list namespace eval Teste [ list \
	    proc Teste {} $teste ] ]
    if { [ catch { set res [ interp eval $resolucao \
	    {namespace eval Teste Teste} ] } erro ] } {
	set res [ list 10 [ list \
		"Erro num comando invocado pelo interface: $erro" ] ]
    }
    return $res
}




# unifica as janelas . dos interpretadores 'a' e 'b'
# sendo 's' o nome de um array que transforma os objectos
# (a menos de frames) de 'a' em janelas de 'b'
proc dominio::unifica {a b s} {
    upvar $s sub

    catch { unset sub }

    filhos $a pa
    filhos $b pb

    if { [ llength [ array names pa ] ] != [ llength [ array names pb ] ] } {
	catch { unset sub }
	return "Deveriam existir [ llength [ array names pa ] ] objectos\
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
		set loa [ lsort [ interp eval $a [ list $wa configure ] ] ]
		set lob [ lsort [ interp eval $b [ list $wb configure ] ] ]
		set j -1		
		set sub($wa) $wb
	    } else {
		catch { unset sub }
		return "Erro no interface. Na posição do objecto $wb devia existir um objecto da classe '[ lindex $pa($wa) 2 ]'"
	    }
	}
    }
    return ""
}

# gera um array com posicão (x,y) e classe
# dos objectos a unificar (exclui as frames por serem usadas no posicionamento)
proc dominio::filhos {intp p {obj .} {x 0} {y 0} {n 0}} {
    incr n
    upvar $n $p pos

    # seleciona os filhos que tenham sido posiconados na janela
    # usa a versão escondida do posicionador porque as expostas
    # foram reescritas devido ás incompatibilidades entre eles
    set children ""
    foreach posiciona { pack grid place } {
	append children [ interp invokehidden $intp  $posiciona slaves $obj ]
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

proc dominio::terminar {} {
#nao faz nada
}


