#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: date.tcl
# 
## Date utilities, mostly for converting dates between integers and text

package provide date 1.0

namespace eval date {

    namespace export sec_date		;## Returns seconds from as a date
    namespace export date_sec		;## Returns seconds formated as a date
    namespace export format_long_time	;## formats time with hours > 24     
}


## Returns seconds from a date (in european format: YY/MM/DD H:M)
proc date::to_sec {date} {

    # -all its not enough, it has to reiterate
    while { [ regsub -all {(\D)(\d)(\D|$)} $date {\10\2\3} date ] } {}
    regsub {^\s*(0\d/)} $date {20\1} date
    regsub {(\d{4})/(\d{2})/(\d{1,2})} $date {\1\2\3} date	
    regsub -all {([\d/-]+)\s+([\d:]+)} $date {\1T\2} date
    regsub -all {(T\d{2}:\d{2})\s*$} $date {\1:00} date
    return [ clock scan $date ]
}

## Returns seconds (long) formated as a date (in european format: YY/MM/DD H:M)
proc date::from_sec {sec} {
    
    return [ clock format $sec -format {%Y/%m/%d %H:%M} ]
}

## Formats time with more than 24 hours (i.e days)
proc date::from_long_sec {sec} {

    set days	[ expr $sec/86400]
    set hours	[ expr $days*24+($sec%86400)/3600]
    return $hours:[ clock format $sec -format {%M:%S} -gmt 1 ]

}

## Formats time acording to saved configuration
proc date::format {time date} {
    variable ::Session::Conf

    switch $Conf(time_type) {
	contest {
	    return [ from_long_sec $time ]
	}
	relative {
	    return -[ from_long_sec [ expr [ clock seconds ] - $date ] ]
	}
	absolute {
	    return [ clock format $date -format {%Y/%m/%d %H:%M} ]
	}
    }
}


