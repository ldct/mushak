#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zï¿½ Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: template.tcl
#
## Package for managing HTML templates. A HTML template is a text file with
## tcl variables that are substituted when template is written.
## Templates can be divided in parts using the special tag <code>!part</code>
## that defined a label with attribute <code>ext</code>. For instance, to
## format a table the programmer usually defines 3 parts in the template 
##
## &lt;!part ext="head"&gt;
## &lt;table&gt;
## &lt;!part ext="line"&gt;
## &lt;tr&gt;&lt;td&gt; $data &lt;/td&gt;&lt;/tr&gt;
## &lt;!part ext="foot"&gt;
## &lt;/table&gt;


#-*-Mode: TCL; iso-accents-mode: t;-*-	

package provide template 1.0

package require translate

namespace eval template {
    set file [ info script ]

    variable HTML
    variable NeedHTTPHeader 0		;# Need HTTP Content Type
    variable Name			;# File name (without .html extension)
    variable Channel	stdout		;# Chaneel where outputs are written
    variable Formatting	""		;# Buffer with HTML formatting
    variable Dir	templates	;# Dir with HTML templates    

    global env				;# the process environment

   
    namespace export load		;## Load file with HTML templated
    namespace export write		;## Write formatting in channel
    namespace export show		;## Show formatting in buffer
    namespace export record		;## Record formatting in buffer
    namespace export formatting		;## Format a given part
}


## Load a file containing an HTML template
proc template::load {{file {}}} {
    variable HTML
    variable Name
    variable Dir

    if { $file == {} } { 
	set call [ lindex [ info level -1 ] 0 ]
	if { ! [ regexp {^(::)?(.*)::(.*)$} $call - - dir name ] } {
	    report_error [ format "cannot figure out package of procedure\
					<code>%s</code>
		      (try defining a path in template::load)" $call ]
	    return -1 ;# error
	}
	set ext ""
    } else {
	set name [ file root [ file tail $file ] ]
	set dir  [ file dir $file ]
	set ext  [ file extension $file ] 
    }
    set Name $name

    set fx [ translate $dir/$name $ext ] 

    if { [catch { set fd [ open $fx r ] } ] } {
	report_error "'$fx' not found"
        return -1 ;# error
    }

    if [ info exists HTML($name,) ] {
	catch { unset HTML($name,) }
    }

    set lineno 0
    set part {}
    while { [ gets $fd line ] != -1} {

	regsub -all {\"|\\|\{|\}|\[|\]} $line \\\\& line

	incr lineno
        set line [ string trim $line ]	
        switch -regexp -- $line {
	    <!part.*> {
		if { [ regexp -nocase {ext=\\"(.*)\\">(.*)} \
			   $line all part pp] } {
		    set HTML($name,$part) ""
		    append HTML($name,$part) $pp
		} else {
		    report_error "$fx: lineno $line: missing ext in part"
		    return -2 ;# report syntax error
		}
	    } <!/part.*> {
		set HTML($name,$part) [ string trim $HTML($name,$part) \n ]
		regsub -all {\\n} $HTML($name,$part) \n\n HTML($name,$part)
		regsub -all {\\t} $HTML($name,$part) \t HTML($name,$part)
		set part {}
	    } default {
		append HTML($name,$part) $line\n
	    }
	}
    }
    close $fd

    return 0 ;# OK
}

## Uses pre translated files with given name
## Hints can be given on possible file extensions (.xml .html or .txt)
proc template::translate {name {hint_ext ""}} {
    variable Dir
    
    # if no hint given on file extensions use these
    if { $hint_ext == "" } { set hint_ext {.html .xml .txt} }

    regsub {^\./} $name {} name
    foreach lang [ translate::langs ] {
	foreach ext $hint_ext {
	    set path ${Dir}/${lang}/${name}${ext}
	    if [ file readable $path ] {
		return $path
	    }
	}
    }
    execute::report_error "cannot find template" ${name}.$hint_ext
}

## Write formatting in channel
proc template::write {{part {}} {name {}}} {
    variable HTML
    variable Channel

    puts -nonewline $Channel [ formatting $part $name 2 ]
}

## Records formatting in buffer to control order
proc template::record {{part {}} {name {}}} {
    variable Formatting

    append Formatting [ formatting $part $name 2 ]
}

## Show formatting in buffer
proc template::show {} {
    variable Channel
    variable Formatting

    puts -nonewline $Channel $Formatting
    set Formatting ""
}

## Returns formatting in buffer
proc template::restore {} {
    variable Formatting

    set f $Formatting
    set Formatting ""
    return $f
}

## Formats using template 
proc template::formatting {{part {}} {name {}} {level 1}} {
    variable HTML

    if { $name == {} } { 
	variable Name
	set name $Name 
    }

   if { [ catch {
       # uplevel already replaced all relevant variables 
       uplevel $level { variable ::Session::Conf }
       set output [ uplevel $level subst 			\
			-nobackslashes -novariables -nocommands \
			\"$HTML($name,$part)\" ]
   } msg ] } {	
       process_error $name $part $msg [ incr level ]
   } else {
      return $output  
   }
}


## Template errors are reported in browser
proc template::process_error {name part msg level} {
    variable NeedHTTPHeader

    if $NeedHTTPHeader {
	puts "Content-type: text/HTML\n"
    }

    switch -regexp -- $msg {
	{no such variable} {
	    regexp {"(.*)"} $msg name_var
	    set msg "variable $name_var undefined"
	    set vars {}
	    foreach var [ uplevel $level info vars ] {
		switch -regexp -- $var {
		    ^tcl_ - 
		    errorCode - 
		    errorInfo -
		    auto_ - 
		    argv -
		    argc -
		    env {}
		    default { lappend vars $var }
		}
	    }
	    append msg "\navailable variables: [ join $vars ]"
	}
	{can't read \"HTML\(} {
	    set msg "Undefined part. Missing line:"
	    append msg "&lt;!part ext=\"$part\"&gt;"
	    
	}  default {
	}
    }    
    report_error "'$name':'$part': $msg</PRE>"	
}


proc template::unset_HTML {} {
    variable Name
    variable HTML

    foreach i [array name HTML] {
        unset HTML($i)
    }    
}

## Reports an error in stdout
proc template::report_error {msg} {
    puts [ format {<PRE>%s</PRE>} $msg ]
}

