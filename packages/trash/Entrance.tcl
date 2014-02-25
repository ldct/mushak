#
# Mooshak: managing  programming contests on the web		Abril 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Part.tcl
# 
# Entrada num  dicionario usados na traducao

package provide Entrance 1.0

package require data



Attributes Entrance {

    Word text	{}
    Translation	text	{}
    Troca	menu	{ não seguinte anterior }
}


# actualiza o dicionario corrente
Operation Entrance::update {} { 

    set dic ${_Self_}/../..
    date::open$dic
    $dic agrega    
    puts [ translate::ifntence "dictionary actualizado" ]

}

