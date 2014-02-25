#
# Mooshak: managing  programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Report_error.tcl
# 
# Erro do sistema

package provide Report_error 1.0

package require data
package require utils

namespace eval Report_error {

    variable Severities {annoying bad nasty}
    variable Trunc	60			;# numero de caracteres da pergunta na listagem
}

Attributes Report_error {

    Reporteddate		{}
    Resumo	text		{}
    Descricao	long-text	{}
    Severity menu		$Severities
    Priority menu		{ 1 2 3 4 5 }
    Resolvido	date		{}
    
}



Operation Report_error::show {} {

}


# mostra linha da listagem de erros
Operation Report_error::list {n m root} {
    variable Trunc

    set sub ${_Self_}
    
    if [ expr $m % 2 ] { set color white } else { set color lightGrey }

    set severity [ translate::ifntence $Severity ]
    set priority $Priority
    set reported [ clock format $Reported -format {%Y/%m/%d %H:%M} -gmt 0 ]

    regsub -all {[\ \n\t\r]+} $Resumo { } resumo

    if { [ string length $resumo ] > $Trunc } {
	set subject [ string range $resumo  0 [ expr $Trunc-3 ]  ]... 
    }


    if $root {
	html::writeroot errors
    } else {
	html::writelin errors
    }

}

