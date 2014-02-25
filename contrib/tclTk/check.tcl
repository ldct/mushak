#!/usr/bin/wish
#
#-*-Mode: TCL; iso-accents-mode: t;-*-	
#
# Procedimentos dependentes do domínio de resolução: TclTk
#						zp@ncc.up.pt   2000
#						
#-

lappend auto_path [pwd]/lib [pwd]/data/dominios/tclTk

package require cgi
package require saferTk
package require match

set TamanhoProgramaMinimo 100

cgi::inicia {

    set classe 0
    set obs ""

    set resolve	resolve	;# interpretador contendo a resolução
    set exemplo	exemplo ;# interpretador contendo a solução

    set attempt $cgi::Campo(Attempt)
    set solution $cgi::Campo(Solution)
    set tests  $cgi::Campo(Tests)

    ::saferTk::avalia $exemplo $solution -100 +100
    ::saferTk::ajusta $exemplo -100 +100
    
    if { [ string length [string trim $attempt] ] < $TamanhoProgramaMinimo } {
	set obs "Programa excessivamente simples "
	append obs "(menos de $TamanhoProgramaMinimo bytes)"
    } elseif { [ catch { 
	set output [ ::saferTk::avalia $resolve $attempt -100 -100 ] 
	::saferTk::ajusta $resolve -100 +100
    } erros ] } {
	set classe 0
	append obs "Erro: $erros \n"
	# já nem tenta fazer mais nada
    } else {
	# actualiza o programa
	catch { interp eval $resolve [ list update idletasks ] } erros
	append obs $erros\n
	::saferTk::ajusta resolve -100 -100

	# compara os interfaces do exemplo e da resolução 
	# (retorna substituições)
	## ::interface::exemplifica    


	if { [ set erros [ match::unifica $exemplo $resolve sub ] ] != "" } {
	    set nerros 0
	    set classe 100	    
	    foreach erro $erros {
		switch -regexp -- $erro {
		    "^Deveriam existir"		{ incr classe -70  }
		    "^Na posição do objecto"	{ incr classe -40  }
		    "^Opcção"			{ incr classe -30  }
		}
		if { [ incr nerros ] < 5 } {
		    append obs $erro\n
		}
	    }
	} else {
	    # verifica a funcionalidade do programa

	    set result [ match::verifica $exemplo $resolve $tests sub ]

	    set nerros 0
	    set classe	100

	    # se nao e uma  lista de erros e melhor dar um geito ...
	    if { $result != "" && ! [ regexp \{ $result ] } { 
		set result [ list $result ] 
	    }
	    
	    foreach erro $result {		

		switch -regexp -- $erro {
		    "^Erro num comando invocado pelo interface" {
			incr classe -40
		    }
		    default	{ incr classe -10	}
		}
		append obs $erro\n
		if { [ incr nerros ] > 3 } {
		    break
		}
	    }

	    if { $classe == 100 } {	
		set estado Concluido
		set obs "Exercício resolvido\n"
	    } 
	}
    }
    if { $classe < 0 } { set classe 0 }

    #
    # Enviar resultados da avaliacao
    #
    set output $obs\n
    foreach canal {stderr stdout} {
	if [ info exists saferTk::Buffer($canal) ] {
	    append output $saferTk::Buffer($canal)
	}
	append output \n
    }
    #append output \n\nclasse=$classe\n
    if { $classe < 100 } { append output $saferTk::Prompt  }
    regsub -all \n $obs { } obs

    # retirar caracteres nulos que baralham as trasnsmissões
    regsub -all \0 $output {} output

    puts "CGI_Content-length: [ string length $output ]"
    puts "CGI_Value: $classe"
    puts "CGI_Remarks: $obs"
    puts ""
    puts -nonewline "$output"
    flush stdout

    #
    # Interpretacao de comandos
    #
    while { $classe < 100 && [ gets stdin command_line ] > -1 } {
	set command_line [ string trim $command_line ]
	set output [ saferTk::interactive_shell $resolve $command_line  ]
	puts "CGI_Content-length: [ string length $output ]"
	puts ""
	puts -nonewline $output
	flush stdout
    }
    
} "text/plain"


destroy .





