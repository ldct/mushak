#
# Mooshak: managing  programming contests on the web		Abril 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Errors.tcl
# 
# Erros do sistema

package provide Errors 1.0

package require data
package require Report_error

namespace eval Errors {

    namespace eval ::utils {}	;# WHY ?!
    namespace import ::utils::*
}


Attributes Errors {
    
     Report_error	dirs	Erro
}

# lista as verificacoes disponiveis
Operation Errors::show {} {

    html::load check_lists.html
    
    html::write head

    foreach fx [ glob -nocomplain ${_Self_}/* ] {
	if { ! [ file isdirectory $fx ] } continue
	set sv [ date::open$fx ]
	set text[ set ${sv}::Nome ]
	html::write lin
    }

    html::write foot
    
}


# listagem de erros
Operation Errors::execute::report_errors {{root 0}} {

    html::load errors.html    

    set fields [ state::define_vars ]

    set update [ expr $time * 60 ]

    html::writehead

    set list [ lsort [ glob -nocomplain ${_Self_}/* ] ]

    state::part {$}page $lines lista paginas ultima
    set n [ expr $last - $page * $lines ]

    foreach sub $list {
	date::open$sub
	$sub lista $n $n $root
	incr n -1
    }

    state::footer$n $page $pages $list $lines $fields
}

