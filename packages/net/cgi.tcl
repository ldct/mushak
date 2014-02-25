#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: cgi.tcl
# 
## CGI requests are processed using the command line given to
## <code>start</code>. Cookies must processed before by the command line
## given to <code>state</code>
##
#-*-Mode: TCL; iso-accents-mode: t;-*-	

package provide cgi 2.0

package require file

namespace eval cgi {

    variable Channel	stdin	;## channel for reading data
    variable Field    		;## variables o CGI communication (array)
    variable Red	0	;## Is data red?
    variable Cookie		;## cookies array
    variable Type		;## Types for eacg CGI variable (array)
    variable Mime text/plain	;## MIME type of last request
    variable BUFFER_SIZE 5000000;## maximum bytes in multipart upload
    variable env		;## environment for execute cgi

    #variable TMP /var/tmp	;## directory of temporary files (upload)

    variable TIMEOUT     2000   ;## timeout or reading message (POST)
    variable STEP         100   ;## time between reading attempts (POST)

    namespace export start	;## processes CGI using argument
    namespace export state	;## processes cooies using argument
    namespace export field	;## returns field value
    namespace export cookie	;## returns field value

    namespace export url_encode		;## Encode argument in URL
    namespace export url_edecode	;## Decode argument in URL
    namespace export url_encode_state   ;## Encode state of CGI variables

}

## Reads in data encoded in application/x-www-urlencoded
proc cgi::urlencoded {} {
    variable env
    variable Field
    variable Channel
    variable Type

    variable TIMEOUT
    variable STEP

    foreach var {Field Type} { if [ info exists $var ] { catch {unset $var} } }

    if { ! [ info exists env(REQUEST_METHOD) ] } {
	return
    }
    switch $env(REQUEST_METHOD) {
	POST {
	    # 
            for { set c 0 } { $c<$TIMEOUT } { incr c $STEP } {
                set data [ split [read $Channel $env(CONTENT_LENGTH)] &]
                if { $data != "" } break
                after $STEP
            }
	}
	GET  {
	    set data [ split $env(QUERY_STRING) &]
	}
    }

    foreach par $data {
	if { [ regexp {^([^=]+)=(.*)} $par - name value ] } {
	    regsub -all -- \r\n [ url_decode $value ] \n value
	    field_value $name $value
	}
    }

}

## Set or add value to the field with given name
proc cgi::field_value {name value} {
    variable Field
    variable FieldCount

    if { [ info exists Field($name) ] } {
	if { $FieldCount($name) == 1 } {
	    set Field($name) [ list $Field($name) ]
	}
	incr FieldCount($name)
	lappend Field($name) $value
    } else {
	set Field($name)  $value
	set FieldCount($name) 1
    }
}


## Decodes text in MIME type <code>x-application/www-url-encoded</code>
proc cgi::url_decode {text} {

    regsub -all {\+} $text { } text
    while { [ regexp -nocase  {%([0-9A-F][0-9A-F])} $text x hexa ] } {
        scan $hexa %x ascii
        set char [ format %c $ascii ]	
	if { [ string compare $char & ] == 0 } { set char \\$char }
        regsub -all \%$hexa $text $char text
    }
    return $text
}

    
## Encodes text in MIME type <code>x-application/www-url-encoded<code>
proc cgi::url_encode {text} {
    
    set new ""
    while { [ regexp -indices {[^ a-zA-Z0-9]} $text par ] } {
	
	set pos [ lindex $par 0 ]
	append new [ string range $text 0 [ expr $pos - 1 ] ]

	set char [ string index $text $pos ]

	scan $char %c ascii
	append new [ format %%%02x $ascii ]

	set text [ string range $text [ expr $pos + 1 ] end ]
    }
    append new $text
    
    regsub -all { } $new + new
    
    return $new
}


## Encodes CGI fields in MIME type <code>x-application/www-url-encoded<code>
proc cgi::url_encode_state {} {
    variable Field

    set state {}
    foreach var [ array names Field ] {
	lappend state $var=[ url_encode $Field($var) ]
    }
    return [ join $state & ]

}



## Reads in data encoded in multipart/form-data 
proc cgi::multipart {} {
    variable env
    variable Channel
    variable Field
    variable Type
    variable ::file::TMP
    variable BUFFER_SIZE

    # cleaning global variables
    foreach var {Field Type} { 
	if [ info exists $var ] { 
	    catch {unset $var} 
	} 
    }

    # preparing temporary directory
    if { ! [ file isdirectory $TMP ] } { 
	exec mkdir -p $TMP	
	file attributes $dir -permissions 0755
    }

    if { ! [regexp {^multipart/form-data; +boundary=(.*)$} \
	    $env(CONTENT_TYPE) x boundary ] } {
	error "multipart: undefined boundary "
    }


    # reading data to buffer 
    fconfigure $Channel -translation binary
    if [ info exists env(CONTENT_LENGTH) ] {
	if { $env(CONTENT_LENGTH) > $BUFFER_SIZE } {
	    error "UPLOAD FAILED: too much data"
	} else {
	    set buffer [ read $Channel $env(CONTENT_LENGTH) ]
	}
    } else {
	set buffer [ read $Channel $BUFFER_SIZE ]
	if { ! [ eof $Channel ] } {
	error "UPLOAD FAILED: connection too slow? Please try again later"
	}
    }

    # processing buffer: avoid using regexp for long buffers
    set len [ expr [ string length $boundary ] + 4 ]
    set buffer [ string range $buffer $len end ] 
    while { [ set p [ string first \r\n--${boundary} $buffer ] ] > -1 } {
	set part [ string range $buffer 0 [ expr $p - 1 ] ]
	set buffer [ string range $buffer [ expr $p + $len + 2 ] end ]
       
	if { ! [ regexp "^(.*?\r\n)\r\n(.*)$" $part - header data ] } {
	    error "multipart: invalid part "
	}
	while { [regexp "^(.*?): (.*?)\r\n" $header - field content header] } {
	    set head($field) [ string trim $content ]	    
	}
	if { $header != "" } { error "multipart: invalid header" }
	regexp { name="([^\"]*)"} $head(Content-Disposition) x name
	if {[regexp { filename="([^\"]*)"} $head(Content-Disposition) x file]} {
	    # file type field
	    regsub -all {\\} $file / file ;# windows -> unix
	    set file [ file tail $file ]

	    if { $file == "" } continue

	    set fd [ open $TMP/$file w ]		
	    puts -nonewline $fd $data
	    close $fd		
	    
	    field_value $name $file
	    
	    if [ info exists cab(Content-Type) ] {
		set Type($name) $cab(Content-Type)
	    } else {
		set Type($name) text/html
	    }
	} else {
	    # normal field
	    field_value $name $data
	}
    }
    
    if { ! [ string equal $buffer "\r\n" ] } {
	error "multipart: final boundary expected"
    } 
}

## Read data from CGI communication
proc cgi::data {} {
    variable env
    variable Red 

    if $Red return

    upvar #0 ::env ::cgi::env ;# use process environment
    
    if { [ info exists env(CONTENT_TYPE) ] } { 
	
	switch -regexp -- $env(CONTENT_TYPE) {
	    multipart/form-data			{ multipart	}
	    application/x-www-form-urlencoded	{ urlencoded	}
	    default				{ urlencoded	}
	}   
    } else {
	urlencoded
    }
    
    set Red 1
}

## Records cookies defined by array in calling environment
proc cgi::record_cookies {a_} {
    upvar $a_ Conf
    variable Cookie

    array unset Cookie 
    foreach name [ array names Conf ] {
	set Cookie($name) $Conf($name)
    }
}

## Recovers cookies defined by array in calling environment
proc cgi::recover_cookies {a_} {
    upvar $a_ Conf
    variable Cookie

    foreach name [ array names Conf ] {
	
	if [ info exists Cookie($name) ] {
	    set Conf($name) $Cookie($name)	    
	} else {
	    set Cookie($name) $Conf($name)
	}
    }
}

## Process state (cookies) using script given as argument
proc cgi::state {script {path /} } {
    variable env

    read_cookies

    data

    if { [ catch { uplevel $script } msg ] } {
	puts  "Content-type: text/HTML"	
	report_error $msg
	exit 
    } else {
	write_cookies $path
    }
}

## Read cookies from HTTP_COOKIE environment variable to 
proc cgi::read_cookies {} {
    variable Cookie
    global env

    if { [ info exists env(HTTP_COOKIE) ] } {
	foreach pair [ split $env(HTTP_COOKIE) \; ] {
	    foreach {name value} [ split $pair = ] {
		set name [ string trim $name ]
		set Cookie($name) $value
	    }
	}
    } 
}

## Write cookies to stdout as part of HTTP header
proc cgi::write_cookies { {path /} } {
    variable Cookie

    foreach name [ array names Cookie ] {
	puts "Set-cookie: $name=$Cookie($name); path=$path;"
    }
}


## Process CGI using script given as argument
proc cgi::start {script {mime text/HTML\n}} {       
    variable Mime
    variable Red

    if { $mime != "" } {
	puts "Content-type: $mime"
    }
    set Mime $mime
    

    if { [ catch { 
	data
	uplevel $script 
    } msg ] } {
	report_error $msg
    }
    set Red 0
}

## Returns the value of a CGI variable. Args: name default.
## A default value can be provided for undefined variables.
proc cgi::field args {
    variable Field

    if { [ llength $args ] < 1 }  {
	error "Undefined CGI variable name"
    } else {
	set var [ lindex $args 0 ]
    }
    if [ info exists Field($var) ] {
	if { $Field($var) == "" && [ lindex $args 1 ] != "" } {
	    error "CGI variable required" $var
	} else {
	    return $Field($var)	    
	}
    } else {
	if { [ llength $args ] < 2 } {
	    error "Undefined CGI variable" $var 

	} else {
	    return [ lindex $args 1 ]
	}
    }
}

## Returns the value of a cookie. Args: name default.
## A default value can be provided for undefined cookies.
proc cgi::cookie args {
    variable Cookie

    if { ! [ array exists Cookie ] } { read_cookies }
	 
    if { [ llength $args ] < 1 }  {
	error "Undefined cookie name"
    } else {
	set var [ lindex $args 0 ]
    }

    if [ info exists Cookie($var) ] {
	if { $Cookie($var) == "" && [ lindex $args 1 ] != "" } {
	    error "Cookie required" $var
	} else {
	    return $Cookie($var)	    
	}
    } else {
	if { [ llength $args ] < 2 } {
	    error "Undefined cookie" $var
	} else {
	    return [ lindex $args 1 ]
	}
    }
}



## Report error to stdout in a format compatible with expected MIME type
proc cgi::report_error {msg {value ""}} {
    variable Mime

    puts "Content-type: $Mime\n"
    if { $value != "" } { append msg ": $value" }
    switch -- [ string tolower $Mime ] {
	text/html {
	    puts [ format "<PRE>%s</PRE>" $msg ]
	}
	default {
	    puts [ format "%s" $msg ]
	}
    }
}
