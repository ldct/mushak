#
# Mooshak: managing  programming contests on the web		Abril 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Answer.tcl
# 
# Resposta a uma pergunta sobre um problema posta por uma (ou varias) equipas
# !! DESACTUALIZADO !!

package provide Answer 1.0

package require data
package require utils

namespace eval Answer {

    namespace eval ::utils {}	;# WHY ?!
    namespace import ::utils::*
}

#-----------------------------------------------------------------------------------
#     Definicao de classe 


Attributes Answer "

	Date		date		{}		
	Time		text		{}		
	Problem		ref		{../../problems}
	Team		ref		{../../groups/*}
	Observations	text		{}
	Question	long-text	{}
	Answer 		long-text	{}
"

# Processes an answer sent by a team
Operation Answer::receive {} {
 
    set Date 		[ clock seconds ]
    set Problem		[ field Problem ]
    set Team		[ field Team	]
    set Question	[ field Question ]
    set Answer		[ field Answer ]

}

Operation Answer::show {}{
    
    html::load answer.html
    html::write 
}

