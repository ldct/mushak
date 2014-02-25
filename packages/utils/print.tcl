#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: print.tcl
# 
## Print HTML formated files using html2ps 
##
## Variable PRINTER holds printer queue. Two special "queues" are 
## recognized by this package:
##		COUNT		returns the number of pages to be printed
##		FILE		outputs to a file (see set_output_filename)

package provide print 1.0

namespace eval print {
    global DIR_BASE 

    if { ! [ info exists DIR_BASE ] } { set DIR_BASE . } ;# for pkgIndex
    
    variable LPR	/usr/bin/lpr			;# printing command
    variable LPQ	/usr/bin/lpq			;# inspect queue
    variable RECODE	/usr/bin/recode			;# recode utf-8 to l1?
    variable PRINTER	DEFAULT				;# default queue
    variable HTML2PS	bin/html2ps-1.0b3/html2ps	;# html->ps command
    variable CONFIG	$DIR_BASE/.html2psrc		;# config file

    variable Orient	""				;# orientation
    variable File	""				;# output filename

    namespace export	ch_orient	;# change printing orientation
    namespace export	data		;# print data passed as argument
    namespace export	data_file	;# print data in argument filename
    namespace export 	set_output_file	;# set output filename
}

# change printing orientation
proc print::ch_orient {text} {
    variable Orient	""

    if [ regexp -nocase landscape $text ] {
	set Orient --landscape
    }
}

# print data passed as argument
# special printer name COUNT returns page count without actually printing
proc print::data {data {printer ""} {config ""}} {
    variable ::file::TMP

    global ENCODING 

    if { [ catch {

	set fd [ open ${TMP}.html w ] 
	fconfigure $fd -encoding $ENCODING ;# force use of ENCODING
	puts $fd $data
	close $fd

	set count [ data_file ${TMP}.html $printer $config ]

    } msg ] } {
	global errorInfo errorCode
	
	error $msg $errorInfo $errorCode
    }

    file delete -force ${TMP}.html
    return $count
}


# print data in filename passed as argument
# special printer name COUNT returns page count without actually printing
proc print::data_file {fx {printer ""} {config ""}} {
    variable LPR
    variable HTML2PS
    variable PRINTER
    variable CONFIG
    variable Orient
    variable ::file::TMP

    recode_iso-latin-1 $fx

    if { $config == ""  } { set config $CONFIG   }
    if { $printer == "" } { set printer $PRINTER }
    set count 0
    if { [ catch {
	eval exec $HTML2PS -f $config $Orient $fx > ${TMP}.ps 2> /dev/null 

	switch -- $printer {
	    COUNT {
		set count [ exec echo | gs ${TMP}.ps 2> /dev/null | grep showpage | wc -l ]
	    }
	    FILE {
		variable File
		
		file rename ${TMP}.ps $File
	    }
	    DEFAULT {
		exec $LPR ${TMP}.ps
	    }
	    default {
		exec $LPR -P$printer ${TMP}.ps
	    }
	}

    } msg ] } {

	global errorInfo errorCode

	error $msg $errorInfo $errorCode
    } 

    file delete -force ${TMP}.ps
    return $count
}

## Sets output filename to be used when printer is FILE
proc print::set_output_file {file} {
    variable File

    set File $file

}



# PS2HTML does not support UTF-8; it has to be recoded to iso-latin-1
# It seams the recode command doesn't work the first time
# but if the file is already in iso-latin-1 it produces an error.
# Workaround: try a few times to recode while not recoded
proc print::recode_iso-latin-1 {fx} {
    variable RECODE

    global ENCODING 

    set count 5 ;#	maximum number of attempts to recode
    for { 

    } {
       [ info exists ENCODING ] 			&& 
       [ string equal $ENCODING utf-8 ] 		&&
       [ string equal [ file_encoding $fx ] utf-8  ]	&&
       $count > 0
   } {
	incr count -1	
    } {
	if { [ catch { 
	    exec $RECODE utf-8..l1 $fx 
	} msg ] } {
	    execute::record_error $msg
	}
    }
}


# Returns file encoding (e.g. utf-8) in lower caps
# The file command doesn't always find encoded chars: removing lower ASCII chars
proc print::file_encoding {file} {
    variable ::file::TMP

    exec tr -d {\000-z} < $file > ${TMP}.encoding
    set encoding [ string tolower [ lindex [ exec file ${TMP}.encoding ] 1 ] ]
    file delete -force ${TMP}.encoding

    return $encoding
}

## Uses lpq to find a default printer
proc print::default_printer {} {
    variable LPQ
    variable PRINTER

    if { [ catch {
	set fd [ open "| $LPQ " r ]
	gets $fd line 
	close $fd
    } ] } {
	return $PRINTER
    } else {
	if [ regexp {^(\w+) is ready$} $line - printer ] {
	    return $printer
	} else {
	    return $PRINTER
	}
    }
}
