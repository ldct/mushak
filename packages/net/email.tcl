#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: email.tcl
# 
## Sending emails, email addresses and MIME

package provide email 1.0

namespace eval email {
    
    variable Sendmail /usr/lib/sendmail	;# sendmail command
    variable MimeType		;# array with (a few) MIME tyeps

    global env

    lappend env(PATH) /usr/lib	;#	usual location of sendmail

    array set MimeType {
	.tgz	application/x-compressed-tar
	.tbz2	application/x-tbz
	.tbz	application/x-tbz
	.tar	application/x-tar
	.zip	application/zip
	.gif	image/gif
	.jpeg	image/jpeg
	.jpg	image/jpeg
	.jpe	image/jpeg
	.png	image/png
	.htm	text/HTML
	.html	text/HTML
	.xml	text/xml
	.xsl	text/xml
	.txt	text/plain
    }

}

## Returns an SMTP mime type based of file extension
proc email::mime {file} {
    variable MimeType

    set ext [ file extension $file ]
    if [ info exists MimeType($ext) ] {
	return $MimeType($ext)
    } else {
	return text/plain		
    }
}

## return a file extendion compatible with given type
proc email::extension_from_mime {mime} {
    variable MimeType

    set data [ array get MimeType ]
    if { [ set pos [ lsearch $data [ string trim $mime ] ] ] > 1 } {

	return [ lindex $data [ expr $pos - 1 ] ]  
    } else {
	return {}
    }
}

## Is this email address valid?
proc email::valid {address} {

    return [ regexp {^[-\w\.]+@[\w-]+(\.[-\w]+)+$} $address ]
}


## Sends a formated file to a set of recipients
proc email::send {from to file log} {
    variable Sendmail

    foreach recipient $to {    
	if { [ catch {                 
	    
	    set fl [open $log a]
	    set now [ clock format [clock seconds] \
		    -format {%d.%m.%Y %H:%M:%S}]
	    puts $fl "$now: sending to $recipient"
	    catch { close $fl }

	    if { [ string trim $from ] == "" } {
		set mailer "$Sendmail"
	    } else {
		set mailer  "$Sendmail -f $from"
	    }
	    set fdw [ open "| $mailer $recipient >> /dev/null" "w" ]
	    set fdr [ open $file "r" ]
	    while { [ gets $fdr line ] !=  -1 } { 
		if { [ catch {
		    puts $fdw [ uplevel subst \"$line\" ] 
		} msg ] } {
		    puts $fdw  "error: $msg: '$line' " 
		}
	    }
	    catch { close $fdr }
	    catch { close $fdw }
	    
	    set fl [open $log a]
	    set now [ clock format [clock seconds] \
			  -format {%d.%m.%Y %H:%M:%S}]
	    puts $fl "$now: OK sent to $recipient."
	    catch { close $fl }
	    
	} msg ] } { 
	    set fl [open $log a]
	    puts $fl "$now: error sending to $recipient: $msg" 
	    catch { close $fl }
	}
    }   
}
