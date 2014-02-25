
package provide html

namespace eval html {

    variable Empty {
	area
	base
	br	
	hr
	img
	input
	link
	meta
	param
    }

    variable Block {
	p
	ul
	ol
	dl
	pre
	div
	center
	blockquote
	form
	isindex
	hr
	table
	select
    }

    variable Inline {
	
	tt
	i
	b
	u
	strike
	big
	small
	sub
	sup

	em
	strong
	dfn
	code
	samp
	kbd
	var
	cite
	
	input
	select
	textarea
	a
	img
	applet
	font
	basefont
	br
	map
    }

    variable Nested {
	ul
	ol
	table
    }


    # elements for which endtags can be omitted
    variable Omit {
	p
	li
	td
	th
	tr
	option
    }

    # tags that terminate an element whose block can be omitted
    variable Terminates
    array set Terminates {
	li { li ul ol }
	td { td th tr table }
	th { th td tr table }
	tr { tr table }
	option { option select }
    }
    set Terminates(p) $Block

    variable Struct {
	html
	head
	body
	title
    }

    variable Tab \t
    variable Horiz	3	;# Número de erros apresentado o aluno
}

proc html::parse {html} {

    set html [ string trim $html ]
    set tree {}
    while { [ regexp -nocase \
	    {^([^<]*)<([^ >]+)([^>]*)>(.*)$} $html - pre tag args html ] } {
	foreach var {pre tag args html} {
	    set $var [ string trim [ set $var ] ]
	}
	set tag [ string tolower $tag ]
	
	if { $pre != {} } { lappend tree [ list {}\
		[ list [ list texto "$pre" ] ] {} ] }

	set arglist [ arglist $args ]
	if { [ 	set container [ container $tag html ] ] == "" } {
	    lappend tree [ list $tag $arglist {} ]
	} else {
	    lappend tree [ list $tag $arglist [ parse $container ] ]
	}
    }
    set html [ string trim $html ]
    if { $html != {} } { lappend tree [ list {} \
	    [ list [ list texto "$html" ] ] {} ] }

    return  [ clean $tree ]
}

# retorna lista de pares atributo-valor 
proc html::arglist {argl} {
    
    #regsub -all {\\"} $argl {"} argl
    set arglist {}
    while { [ regexp {^[^a-z]*([a-z1-9]+)[^=]*=(.*)} $argl - name rest ] } {
	set value ""
	if { [ regexp "^\[ \n\t]*\[\'\"\](.*)$" $rest - rest ] } {
	    if { ! [ regexp {^([^"']*)["'](.*)$} $rest - value argl ] } {
		set value $rest
		set argl ""
	    }
	} else {
	    regexp "^(\[^ \n \t]*)(.*)" $rest - value argl
	}
	lappend arglist [ list $name $value ]
    }
    return $arglist
}
	
# remove elementos não essenciais á formatação
# (não tem que ser recursivo por ser chamado em cada nivel do parsing)
proc html::clean {tree} {
    variable Struct

    set new {}
    foreach node $tree {
	foreach {element args desc} $node {}
	
	# retirar anotações de finalização não casadas
	if { [ regexp {^/} $element ] } { continue }

	if { [ lsearch $Struct $element ] > -1 && $args == {} } {
	    foreach node $desc {
		lappend new $node
	    }
	} else {
	    lappend new $node
	}
    }

    # remove a última coluna duma tabela se estiver vazia
    foreach {element args desc} [ lindex $new end ] {
	if { [ string equal $element "td" ] && $args == {} && $desc == {} } {
	    set new [ lreplace $new end end ]
	}
    }

    return $new
}
	
# dada a lista com o resto do HTML retira o contentor da anotação
proc html::container {tag t} {
    upvar $t html
    variable Empty
    variable Omit
    variable Block
    variable Terminates
    variable Inline
    variable Nested

    if { [ lsearch $Empty $tag ] > -1 } {
	# a anotação não admite contentor
	set container ""
    } elseif { [ lsearch $Omit $tag ] > -1 } {
	# a anotação de finalização pode ser omitida
	set container ""
	set found 0
	while { [ regexp -nocase {^([^<]*)<(/?)([a-z0-9]+)(.*)$} $html \
		- p e t r] } {
	    append container $p
	    if { ! [ regexp {^([^>]*>)(.*)$} $r - pre html ] } {
		set pre ""
		set html $r
	    }
	    if { $e == "" } {
		if { 
		    [ info exists Terminates($tag) ] && 
		    [ lsearch $Terminates($tag) $t ] > -1 
		} {
		    set html "<$t$r"
		    set found 1
		    break 
		} else {
		    append container <${t}${pre}
		}
	    } else {
		if { [string compare $t $tag] == 0 } { 
		    set found 1
		    break 
		} elseif { 
			  [ info exists Terminates($tag) ] && 
			  [ lsearch $Terminates($tag) $t ] > -1 
		      } {
		    set html <$e${t}${pre}$html
		    set found 1
		    break
		} else {
		    append container <$e${t}${pre}
		}
	    }
	    
	}
	if { ! $found } {
	    append container $html
	    set html ""
	}
    } elseif { [ lsearch $Nested $tag ] > -1 } { 
	# certos elementos (como as tabelas) podem ocorer encaixados)
	set container ""
	set level 1
	while { [ regexp -nocase "^(.*)<(/?)${tag}(.*)$" $html - p e r] } {
	    append container $p
	    if [ regexp {^([^>]*>)(.*)$} $r - pre html ] {
		if { $e == "" } {
		    incr level
		    append container <${t}${pre}
		} else {
		    incr level -1 
		    if { $level == 0 } {
			break
		    } else {
			append container <${t}${pre}
		    }
		}
	    }
	}
    } else {
	# em geral o elemento fecha com um fim-de-anotaçao ou vai até ao fim
	if { [ regexp -nocase -indices </${tag}\[^>\]*> $html pos ] } {
	    # tem uma anotação de finalização válida
	    set a [ lindex $pos 0 ]
	    set b [ lindex $pos 1 ]
	    set container [ string range $html 0 [ incr a -1 ] ]
	    set html [ string range $html [ incr b ] end ]
	} else {
	    set container $html
	    set html ""
	}
    }
    # puts "[string toupper $tag]: $container"
    return $container
}

proc html::contabiliza {tree elementos_ atributos_ textos_ {nivel 1}} {
    upvar $nivel $elementos_ 	elementos
    upvar $nivel $atributos_ 	atributos 
    upvar $nivel $textos_	textos

    incr nivel

    foreach node $tree {
	if { [ lindex $node 0 ] == "" } {
	    incr textos
	} else {
	    incr elementos
	    incr atributos [ llength [ lindex $node 1 ] ]
	    contabiliza [ lindex $node 2 ] \
		    $elementos_ $atributos_ $textos_ $nivel
	}
    }
}

proc html::classify {compara solucao} {

    set elementos 0
    set atributos 0
    set textos    0

    contabiliza $solucao elementos atributos textos
    
    set erro_ele 0
    set erro_atr 0
    set erro_txt 0

    foreach erro $compara {
	switch -regexp $erro {
	    {elemento .* em falta.*} 	{ incr erro_ele } 
	    {elemento .* a mais.*}   	{ incr erro_ele } 

	    {atributo .* em falta.*} 	{ incr erro_atr } 
	    {atributo .* errado.*}   	{ incr erro_atr } 
	    {atributo .* a mais.*}   	{ incr erro_atr } 

	    {texto .* falta}  		{ incr erro_txt }
	    {texto errado} 		{ incr erro_txt }
	    {texto .* a mais} 		{ incr erro_txt }
	}
    }        

    if $elementos {
	set classe [ expr 100 - \
		int(pow(double($erro_ele) * 100 / $elementos,1.1))]
    } else {
	set classe 100
    }
    set erros [ expr $erro_atr + $erro_txt ]
    set decor [ expr $atributos + $textos ]
    if $decor {
	incr classe [ expr - int(pow(double($erros) * 50 / $decor,1.1))]
    }

    if { $classe < 0 } { set classe 0 }
    if { $classe == 100 && ($erros + $erro_ele) > 0 } { set classe 99 }
    return $classe
}

# produz texto com ajudas o luno a partir da comparação da solução e tentativa 
proc html::tips {compara} {
    variable Horiz

    set l {}
    set p 0
    for { set i 0 } { $i < [ llength $compara ] } {  } {
	set e [ lindex $compara $i ]
	for { incr i ; set n 1 } { 
	    [ string compare $e [ lindex $compara $i ] ] == 0 
	} {  incr i ; incr n }  {}
	if { $n > 1 } { append e " ($n vezes)" }
	lappend l $e 
    }

    set tips [ join [ lrange $l 0 [ expr $Horiz - 1 ] ] \n ]
    set n [ llength $l ]
    if { $n == $Horiz + 1 } {
	append tips \n[ lindex $l $Horiz ]
    } elseif { $n > $Horiz } {
	append tips "\n -- existem mais [ expr $n - $Horiz ] erros -- "
    }
    return $tips
}


proc html::compare  {solution attempt} {
    compare_list $solution $attempt
}

# compara uma lista de anotações
proc html::compare_list {solution attempt} {
    
    set erros {}
    set erros_desc {}
    foreach sol $solution {	
	set s [ lindex $sol 0 ]
	set match 0
	for { set p 0 } { $p < [ llength $attempt ] } { incr p } {
	    set att [ lindex $attempt $p ]
	    set a [ lindex $att 0 ]
	    if { [ string compare $a $s ] == 0 } {
		# tem a mesma anotação donde presumo que são o mesmo
		set erros_desc [ concat $erros_desc \
			[ compare_set  [ lindex $sol 1 ] [ lindex $att 1 ]  \
			[ expr [ string compare $s "" ] == 0 ] ] ]
		set erros_desc [ concat $erros_desc \
			[ compare_list [ lindex $sol 2 ] [ lindex $att 2 ] ] ]
		set match 1
		break
	    }
	}

	if $match  {
	    set attempt [ lreplace $attempt $p $p ]
	} else {
	    if { $s == "" } {
		set texto [ lindex [ lindex [ lindex $sol 1 ] 0 ] 1 ]
		lappend erros_desc "sequência de texto '$texto' em falta"
	    } else {
		lappend erros "elemento '$s' em falta"
		set erros_desc [ concat $erros_desc \
			[ compare_list [lindex $sol 2] {} ] ]
	    }
	}
    }
    foreach att $attempt {
	set a [ lindex $att 0 ]
	if { $a == "" } {
	    set texto [ lindex [ lindex [ lindex $att 1 ] 0 ] 1 ]
	    lappend erros_desc "sequência de texto '$texto' a mais"
	    if [ regexp -nocase {^<([a-z0-9]+) } $texto - tag] {
		lappend erros_desc "NOTA: talvez falte '>' na anotação '$tag'"
	    }
	} else {
	    lappend erros "elemento '$a' a mais"
	    set erros_desc [ concat $erros_desc \
		    [ compare_list [lindex $att 2] {} ] ]
	}
    }
    return [ concat $erros $erros_desc ]
}

# compara um conjunto de atributos
proc html::compare_set {solution attempt {texto 0}} {

    set erros {}
    foreach sol $solution {
	set s [ lindex $sol 0 ]
	set match 0
	for { set p 0 } { $p < [ llength $attempt ] } { incr p } {
	    set att [ lindex $attempt $p ]
	    set a [ lindex $att 0 ]
	    if { [ string compare $a $s ] == 0 } {
		# tem a mesma nome donde presumo que são o mesmo
		if { [ string compare [ lindex $sol 1 ] [ lindex $att 1 ] ] } {
		    if $texto {
			lappend erros "texto errado '[ lindex $att 1 ]' (esperava '[ lindex $sol 1 ]')"
		    } else {
			lappend erros "valor de atributo '$s' errado"
		    }
		}
		set match 1
		break
	    }
	}
	if $match  {
	    set attempt [ lreplace $attempt $p $p ]
	} else {
	    lappend erros "atributo '$s' em falta"
	}
    }
    foreach att $attempt {
	set a [ lindex $att 0 ]
	lappend erros "atributo '$a' a mais"
    }
    return $erros
}


proc html::show {tree {tab 0}} {
    set output ""
    set next [ expr $tab + 1 ]
    foreach node $tree {	
	set tag [ lindex $node 0 ]
	set atr [ lindex $node 1 ]
	set sub [ lindex $node 2 ]
	
	append output "[ tab $tab][ string toupper $tag ]: "
	append output [ string tolower $atr ]\n
	append output [ html::show $sub $next ]
    }
    return $output
}

# produz uma string de tabelamento com n posições
proc html::tab {n} {
    variable Tab 
    set tab ""
    for { set i 0 }  { $i < $n } { incr i } {
	append tab $Tab
    }
    return $tab
}

proc html::html2iso {texto} {

    regsub -all {\&atilde;} $texto ã texto
    regsub -all {\&Atilde;} $texto Ã texto
    regsub -all {\&otilde;} $texto õ texto
    regsub -all {\&Otilde;} $texto Õ texto

    regsub -all {\&acirc;} $texto â texto
    regsub -all {\&Acirc;} $texto Â texto
    regsub -all {\&ecirc;} $texto ê texto
    regsub -all {\&Ecirc;} $texto Ê texto
    regsub -all {\&ocirc;} $texto ô texto
    regsub -all {\&Ocirc;} $texto Ô texto

    regsub -all {\&ccedil;} $texto ç texto
    regsub -all {\&Ccedil;} $texto Ç texto

    regsub -all {\&aacute;} $texto á texto
    regsub -all {\&eacute;} $texto é texto
    regsub -all {\&iacute;} $texto í texto
    regsub -all {\&oacute;} $texto ó texto
    regsub -all {\&uacute;} $texto ú texto

    regsub -all {\&Aacute;} $texto Á texto
    regsub -all {\&Eacute;} $texto É texto
    regsub -all {\&Iacute;} $texto Í texto
    regsub -all {\&Oacute;} $texto Ó texto
    regsub -all {\&Uacute;} $texto Ú texto

    regsub -all {\&agrave;} $texto à texto
    regsub -all {\&Agrave;} $texto À texto

    return $texto
}


proc teste {} {
    global  html 

    set html [ exec cat [ glob ~/public_html/ganesh/introducao.html ] ]

    #html::parse $html
    html::parse $::bug

}

set bug {


<table><td><y
</table>



}