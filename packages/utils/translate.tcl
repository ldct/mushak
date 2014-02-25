#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: translate.tcl
# 
## Translation of sentences and  files.
## Language is defined in the browser configuration and received 
## in the environment variable HTTP_ACCEPT_LANGUAGE as a 2 letter
## code based on ISO 639 (a 2-2 letter code can be used for language
## variants such as pt-br for Brazilian Portuguese).
##
## Dictionaries are kept in a directory (DicHome) in a file with
## the same name as the language code and extension ".tcl". 
##
## The key in the dictionary is the word/sentence in English.

package provide translate 1.0

namespace eval translate {
    
    variable Dic			;# array with dictionary
    variable DicHome	templates	;# directory with dictionaries 
    variable Langs	{}		;#  Accepted languages (ISO code)		
}

## Return list of languages (ISO codes) ordered by preference
proc translate::langs {} {
    global env
    variable ::Session::Conf
    variable Langs

    if { $Langs == {} } {
	if { 
	    [ info exists Conf(language) ] &&
	    $Conf(language) != ""
	} {
	    # if a language was selected on Mooshak's interface use it
	    set Langs $Conf(language)
	} else {
	    # otherwise check if language preferences from HTTP request
	    if [ info exists env(HTTP_ACCEPT_LANGUAGE) ] {

		regsub -all {( |,)+} $env(HTTP_ACCEPT_LANGUAGE) { } Langs
		regsub -all {(.+);.*?} $Langs {\1} Langs
	    } else {
		set Langs en
	    }
	}
	# just in case those languages are not available
	# English (en) is added as default language
	lappend Langs en
    }

    # {en-us;q=0.8} 	-> 	en
    regsub -all  {{([\w-]+);q=[\d\.]+}} $Langs {\1} Langs

    return $Langs
}

## reload dictionary
proc translate::reload {} {
    variable Langs 
    variable Dic

    set Langs {}
    array unset Dic
    load
}


## Load anavailable dictionary
proc translate::load {} {
    variable Dic
    variable DicHome

    foreach lang [ langs ] {	

	if [ string equal $lang en ] {
	    # en is the default language and doesn require a dictionary
	    return
	} elseif { [ file readable ${DicHome}/${lang}.dic ] } {
	    source ${DicHome}/${lang}.dic
	    return
	}
    }
}

## Translate a sentence given as argument
proc translate::sentence {str} { 
    variable Dic
    
    if [ info exists Dic($str) ] {
	return $Dic($str)
    } else {
	return $str
    }
}

## Translate a list of sentences given as argument
proc translate::sentence_list list {
    variable Dic

    set trans {}
    foreach str $list {
	if [ info exists Dic($str) ] {
	    lappend trans $Dic($str)
	} else {
	    lappend trans $str
	}
    }
    return $trans 
}

## Create a variable with label name
proc translate::labels args {

    foreach var $args {
	upvar $var $var
	regsub -all _ $var { } tmp
	set label [ string trim $tmp ]
	if { ! [ string equal [ string index $tmp 0 ] " " ] } {
	    set label [ string totitle $label ]
	}
	set $var [ translate::sentence $label ]
    }

}

