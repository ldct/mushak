#
# Mooshak: managing programming contests on the web		July 2011
# 
#			Zé Paulo Leal 		
#			zp@dcc.up.pt
#
#-----------------------------------------------------------------------------
# file: latex.tcl
# 
## Import/export to LaTeX with a special style (mooshakquiz.sty)

package provide lo 1.0

namespace eval latex {

    # regular expressions used in parsing
    variable GROUP_RE		{\\begin{quizgroup}(.*?)\\end{quizgroup}}
    variable SIZE_RE 		{^\{(\d+)\}}
    variable TITLE_RE		{^(.*?)\\begin\{quizquestion\}}
    variable QUESTION_RE	{\\begin{quizquestion}(.*?)\\end{quizquestion}}
    variable ASK_RE		{^(.*?)\\begin\{quizchoice\}}
    variable CHOICE_RE		{\\begin{quizchoice}(.*?)\\end{quizchoice}}
    variable STATE_RE 		{^\{(true|false)\}}

    # templates to produce Mooshak's XML 
    variable QUIZ_TEMPLATE   	\
	"<Quiz>%s\n</Quiz>"
    variable GROUP_TEMPLATE  	\
	"\n\t<QuizGroup xml:id='%s' Title='%s' Size='%s'>%s</QuizGroup>\n"
    variable QUESTION_TEMPLATE  \
	"\n\t\t<QuizQuestion xml:id='%s' Ask='%s' Points='%s'>%s</QuizQuestion>\n"
    variable CHOICE_TEMPLATE  	\
	"\n\t\t\t<QuizChoice xml:id='%s' Answer='%s' Status='%s'/>\n"

}

## Converts a LaTeX using mooshakquiz.sty to Mooshaks' XML
proc latex::convert {tex} {
    variable GROUP_RE	
    variable SIZE_RE 	
    variable TITLE_RE	
    variable QUESTION_RE
    variable ASK_RE	
    variable CHOICE_RE	
    variable STATE_RE 	

    variable QUIZ_TEMPLATE
    variable GROUP_TEMPLATE    
    variable QUESTION_TEMPLATE
    variable CHOICE_TEMPLATE  

    ## remove comments (part of the struture may have been commented out)
    regsub -all {%[^\n]*\n} $tex {} tex

    set images {}			;# collects images (not being used)

    set groups_xml	""
    set group_counter 	0
    foreach {- group} [ regexp -all -inline $GROUP_RE $tex] {
	incr group_counter
	
	if { [ regexp  $SIZE_RE $group  - size ] } {
	    regsub $SIZE_RE $group {} group
	} else {
	    set size ""
	}
	if { ! [ regexp $TITLE_RE $group - title ] } {
	    set title ""
	}	    

	set questions_xml	""
	set question_counter 	0
	foreach {- question} [ regexp -all -inline $QUESTION_RE $group] {
	    incr question_counter

	    if { ! [ regexp $ASK_RE $question - ask ] } {
		set ask "?"
	    }	    
	    
	    prepare_text ask 
	    set choices_xml	""
	    set choice_counter	0

	    foreach {- choice} [regexp -all -inline $CHOICE_RE $question] {
		incr choice_counter
		
		if {  [ regexp  $STATE_RE [string trim $choice]  - state ] } {
			regsub $STATE_RE $choice {} choice
		} else {
		    set state ""
		}
		
		prepare_text choice
		set choice_id [format "G%02d.Q%02d.C%02d" \
			    $group_counter $question_counter $choice_counter ]
		append choices_xml [ format $CHOICE_TEMPLATE	\
				$choice_id $choice $state ]

	    }
	    set points 1
	    set question_id [format "G%02d.Q%02d" \
				 $group_counter $question_counter]
	    append questions_xml [ format $QUESTION_TEMPLATE	\
				$question_id $ask $points	\
				$choices_xml ]
	}
	set group_id [ format "G%02d" $group_counter ]
	append groups_xml [ format $GROUP_TEMPLATE	\
				$group_id $title $size	\
				$questions_xml ]
    }

    return [ format $QUIZ_TEMPLATE $groups_xml ]
}


# convert XML special characters to XML entities
proc latex::prepare_text {text_} {
    upvar $text_ text

    regsub -all {&} 	$text {\&amp;}	text
    regsub -all {<} 	$text {\&lt;}	text
    regsub -all {>} 	$text {\&gt;}	text
    regsub -all {\"} 	$text {\&quot;} text
    regsub -all {\'} 	$text {\&apos;}	text
    
}



### ---------------   Post Processing -------------------------------


## Post process quiz after importing structure converting
##	LaTeX formatting to HTML, when outside expressions ($ $)
##	LaTeX graphics into HTML images
##	LaTeX expressions into MathJAX blocks
## but just on certain fields (Title, Ask, Answer)
proc latex::post_process  {dir} {

    set text [ file::read_in $dir/.data.tcl ]


    if [ regexp {set\s+(Title|Ask|Answer)\s+{(.*)}} $text def var value ] {

	convert_envirs_and_styles value
    
	convert_text_out_of_expressions value
	
	# convert LaTeX expression delimiters to MathJax delimiters 
        regsub -all {\$\$(.*?)\$\$} $value {\[\1\]} value
        regsub -all {\$(.*?)\$}     $value {\(\1\)} value

	convert_graphics_to_images value

	replace text $def [ format {set %s {%s}} $var $value ]
    }

    set fd [ open  $dir/.data.tcl "w" ]
    puts $fd $text
    catch { close $fd }

    foreach sub [ glob -type d -nocomplain $dir/* ] {
	post_process $sub
    }
}

## Convertes LaTeX formatting to HTML when not between $ $ 
proc latex::convert_text_out_of_expressions {text_} {
    upvar $text_ text

    set original $text
    set text ""

    set start 0
    foreach { pair } [ regexp  -all -inline -indices \
		       {(^|[^\\])\${1,2}[^\\]*[^\\]\${1,2}} $original] {
	    foreach {start_expr end_expr} $pair {}

	    set nonexpr [ string range $original $start $start_expr ] 
	    set anexpr  [string range $original $start_expr $end_expr]

	    convert_chars nonexpr
	    append nonexpr
	    append text $nonexpr $anexpr
	    
	    set start [ expr $end_expr + 1 ]
	}
    set nonexpr [ string range $original $start end ]
    convert_chars nonexpr
    append text $nonexpr
}



variable latex::LATEX_ENVIR_RE {\\begin{%s}(.*?)\\end{%s}} 
variable latex::LATEX_STYLE_RE {\\%s{(.*?[^\\])}} 

## Convert LaTeX styles into HTML styles
proc latex::convert_envirs_and_styles {text_} {
    upvar $text_ text
    variable LATEX_ENVIR_RE
    variable LATEX_STYLE_RE

    foreach {latex_envir html_envir} {
	verbatim	pre
    }  {
	set latex_envir_re [ format $LATEX_ENVIR_RE $latex_envir $latex_envir ]

	foreach {match styled} [regexp -all -inline $latex_envir_re $text] {
	    replace text $match \
		[ format {<%s>%s</%s>} $html_envir $styled $html_envir ]
	}
    }

    foreach {latex_style html_style} {
	texttt code
	textbf b
	textit i
	underline u
	emph i
    }  {
	
	set latex_style_re [ format $LATEX_STYLE_RE $latex_style ]

	foreach {match styled} [regexp -all -inline $latex_style_re $text] {
	    replace text $match \
		[ format {<%s>%s</%s>} $html_style $styled $html_style ]

	}
    }
}


## replace in given variable named $text_ string $from by string $to
proc latex::replace {text_ from to} {
    upvar $text_ text


    set first [ string first $from $text ]
    set last  [ expr $first + [ string length $from ] - 1 ]
    set text  [ string replace $text $first $last $to ]
}


## Convert LaTeX chars into HTML chars
proc latex::convert_chars {text_} {
    upvar $text_ text

    ## replace LaTeX diacritics by UTF-8 chars
    foreach {latex utf8} { 
	{\\c{c}} ç 
	{\\~a} ã	{\\'a} á	{\\`a} à 
	{\\~e} ẽ	{\\'e} é 	{\\`e} è  
			{\\'i} í	{\\`i} ì
	{\\~o} õ 	{\\'o} ó	{\\`o} ò 
			{\\'u} ú 	{\\`u} ú 

    } {
	regsub -all $latex $text $utf8 text
    }
    

    ## replace LaTeX special chars
    foreach {latex special} {
	{\\\\}    	{<br/>}
	{\\ }		{\&#32;}
	{``}		{\&#34;}		
	{''}		{\&#34;}		
	{\\#}		{\&#35;}
        {\\\$}          {\&#36;}
	{\\%}		{\&#37;}
	{\\\&}		{\&#38;}	
	{\\backslash}   {\&#92;}
	{\\_} 		{\&#95;}	
        {\\\{}  	{\\\&#123;}
        {\\\}}  	{\\\&#125;}

    } {
	regsub -all $latex $text $special text
    }
}


variable latex::GRAPHICS_RE {\\includegraphics(?:\[([^\]]+)\])?{([^\}]+)}} 
variable latex::OPTION_RE {(width|height)=(\d+\w+)}
proc latex::convert_graphics_to_images {text_} {

    upvar $text_ text
    variable GRAPHICS_RE 
    variable OPTION_RE

    foreach {match options pathname} [regexp -all -inline $GRAPHICS_RE $text] {
	lappend images pathname 
	set image [ file tail $pathname ]
	
	set style {}
	foreach {option name value} [regexp -all -inline $OPTION_RE $options] {
	    lappend style [ format {%s: %s;} $name $value ]
	}
	
	replace text $match 					\
	    [ format {<img style="%s" src="?image+%s"/>} 	\
		  [ join $style { } ] $image ]
    }

}

