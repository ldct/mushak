#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: layout.tcl
# 
## Layout utilities, mostly HTML layout procedures

package provide layout 1.0

namespace eval layout {
    
    namespace export alert		;## Show mesage in JS dialog
    namespace export window_open	;## Opens URL in window
    namespace export window_close	;## Close current window
    namespace export window_close_after_waiting ;## Wait & close current window

    namespace export redirect		;## HTML code for redirecting a page.
    namespace export menu		;## Generates HTML menu
    namespace export choose		;## Set of radio buttons
    namespace export color		;## formats HTML with given color
    namespace export toggle_color	;## Toggle color variable from couter

    namespace export remove_html_tags	;## Remove html tags from text string
    namespace export protect_html	;## Protect HTML special characters
    namespace export show_white_chars	;## Replace white with visible chars
    namespace export show_white_chars_html ;## Same for HTML 

    namespace export truncate_label	;## Truncate label to given size
    namespace export fit_label		;## Remove middle names to fit size

}

## shows a message in a JS window
proc layout::alert {message {value ""} {context ""}} {

    set message [ translate::sentence $message ]
    if { $value != "" } { append message [ format {: %s} $value ] }
    if { $context != "" } { set message [ format {%s: %s} $context $message ] }

    puts [ format {<script>alert('%s');</script>} [ protect_js $message ] ]
}


## opens URL in window
proc layout::window_open {url {window _self} {notify 1}} {
    puts [ format {<script>window.open('%s','%s');</script>} $url $window ]
    # this message will be seen in browsers without window.open()
    # such as those controlling pop-ups (such as mozilla firebird)
    
    if $notify {
	puts [ format {<h2>%s</h2>} \
	       [ translate::sentence \
		     "Please disable pop-up blocking for this site" ] ]
    }
}

## closes current window
proc layout::window_close {} {
    puts [ format {<script>window.close();</script>} ]
    
}

## close window ater waiting $time (milisecs?)
proc layout::window_close_after_waiting {{time 1000}} {
    puts [ format {<script>setTimeout("window.close()",%s);</script>} $time ]
}


## formats html for help button 
proc layout::help_button {path} {
    variable ::Session::Conf

    return [ format {
	<form onSubmit="return false;">	
		<input 
			type="image"
			onClick="window.open(
					'%s?help+%s',
					'help',
					'width=800,height=500,scrollbar=1'); "
			border="0" 
			src="../../icons/unknown.png"
			align="left">
	</form>
    } $Conf(controller) $path ]
}

## formats html for inlined help message
proc layout::help_text {var text} {

    return [ format {<a href="javascript:alert('%s')" 
	onMouseOver="window.status='More info on %s'; return true"
	onMouseOut="window.status=''; return true">
	<img alt="help" border="0" src="../../icons/unknown.png"</a>} \
		 [ protect_js $text ] $var ]
}

#    return [ format {
#	<div style="display: inline;">
#	<a href="javascript:this.parent.style.display='none'">more help...</a>
#	</div>
#	<div style="display: none;">
#	<a href="javascript:this.parent.style.display='none'">hide help</a>
#	<pre>%s</pre>
#	</div>
#   } $text ]
#}

## Puts in stdout the HTML code for redirecting a page.
proc layout::redirect {page {time 0}} {
    puts [ format {<META HTTP-EQUIV="Refresh" CONTENT="%d; URL=%s">} \
	       $time $page ]
}


## Remove html tags from text string
proc layout::remove_html_tags {text} {
    
    regsub -all {<br[^>]*>}    $text {\n} 	text
    regsub -all {</?p[^>]*>}   $text {\n\n} 	text
    regsub -all {</?pre[^>]*>} $text {\n\n} 	text
    regsub -all {</?[^>]+>}    $text {} 	text

    return $text
}

## Protect HTML special characters
proc layout::protect_html {text} {

    regsub -all & $text {\&amp;} text   
    regsub -all < $text {\&lt;}  text   
    regsub -all > $text {\&gt;}  text  

    return $text
}

## Protect JavaScript special characters
proc layout::protect_js {text} {
    regsub -all "\n" $text {\n} text
    regsub -all {\'} $text {` } text
    regsub -all {\"} $text {``} text

    return $text
}


## Replace white characteres with visible characters avoiding HTML formating
proc layout::show_white_chars_html {html} {

    set new ""
    while {[regexp  {^(.*?)<([^>]*)>([^<]*)(.*)$} $html - pre tag con html]} {
	append new [ show_white_chars $pre]<$tag>[ show_white_chars $con ]
    }
    append new [ show_white_chars $html ]

    return $new
}

## Replace white characteres with visible characters
proc layout::show_white_chars {text} {

    set attrib size
    set value -1

    regsub -all {\ } $text "<font $attrib=\"$value\">\[\]</font>"   text
    regsub -all {\t} $text "<font $attrib=\"$value\">\\t\t></font>" text
    regsub -all {\n} $text "<font $attrib=\"$value\">\\n\n</font>"  text
    
    return $text
}



## Returns a string with an HTML formated menu
proc layout::menu {name values value { texts {} } { size 1 } 
		   { onChange "this.form.submit();" }
		   { cssClass Normal }
	       } {

    set i 0
    set f {<select size="%s" name="%s" onChange="%s" class="%s">} 
    set html \n[ format $f $size $name $onChange $cssClass ]
    foreach item $values {
	if [ string compare $item $value ] {
	    set sel ""
	} else {
	    set sel " selected"
	}
	if { $texts == "" } {
	    set text [ translate::sentence $item ]
	} else {
	    set text [ lindex $texts $i ] 
	}

	append html [ format {<option%s value="%s">%s} $sel $item $text ]\n
	incr i
    }
    append html "</select>"
    return $html    
}

## Returns a string with an HTML formated list of radio buttons
proc layout::choose {name values value {texts {}} } {
    set html ""

    set i 0
    set layout {<input type="radio" name="%s" value="%s"%s onClick="this.form.submit()"> %s }

    foreach item $values {
	if [ string compare $item $value ] {
	    set sel ""
	} else {
	    set sel "checked"
	}
	if { $texts == "" } { 
	    set text [ translate::sentence $item ]
	} else { 
	    set text [ lindex $texts $i ]
	}
	append html \n[ format $layout $name $item $sel $text]
	incr i
    }
    return $html\n
}

## Modifies the text in the variable to be formated with the specified color
proc layout::color {text_ color} {
    upvar $text_ text

    set text [ format {<font color="%s">%s</font>} $color $text ]
}

## Toggle color in variable based on couter
proc layout::toggle_color {n_ color_ {colors {white lightGrey}} } {
    upvar $n_ n
    upvar $color_ color

    if [ expr [ incr n ] % 2 ] { 
	set color [ lindex $colors 0 ]
    } else { 
	set color [ lindex $colors 1 ]
    }

}

# strip HTML tags
proc layout::strip_tags {text} {

    regsub -all {<[^>]+>} $text {} text
    return $text
}


## Returns a label truncated the given size
proc layout::truncate_label {text size} {

    if { [ string length $text  ] > $size } {
	return [ format {%s...} [ string range $text 0 [ expr $size - 3 ] ] ]
    } else {
	return $text
    }
}

## Returns a label fitting the given size
## Label is assumed to be a (long portuguese) name and 
## middle names are removed when needed 
proc layout::fit_label {name {size 20}} {
    variable MaxLabelSize

    regsub -all "_" $name " " name

    if { [ string length $name ] > $size } {	

	regsub -all {\d} $name {} name

	if [ catch {
	    set new ""
	    set left ""
	    set right ""
	    set pos 0
	    set left_side 1
	    
	    while { [ string length ${left}...${right} ] < $size } {
		set new ${left}...${right}
		if $left_side {
		    lappend left [ lindex $name $pos ]
		    set left_side 0
		} else {
		    set right [ concat [ lindex $name end-$pos ] $right ]
		    set left_side 1
		    incr pos
		}
	    }
	    set name $new
	} ] {
	    set name [ string range $name 0 [ expr $size-3 ] ]... 
	}
	
    }
    return $name
}
