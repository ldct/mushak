#
# Mooshak: managing programming contests on the web		APril 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Contests.tcl
# 
## The contest directory.
##

package provide Contests 1.0

package require data
package require file
package require data4mining

namespace eval Contests {

    variable DATA_FILE_NAME	submissions_data.txt

    array set Tip {
	Latin-1->uft-8... "Convert all contest Latin-1 (ISO-8859) files to UTF-8"
	Utf-8->latin-1... "Convert all contest UTF-8 files to Latin-1 (ISO-8859)"
    }
}

Attributes Contests {

    Contest	dirs	Contest

}

## Generates an HTML selector for contest
##  active	(boolean) select only active contests { ready running closed }
##  update 	(boolean) update on change
##  registrable	(boolean) list only if registrable
Operation Contests::selector { contest_ 
    {active 1} {update 1} {registrable 1}
} {
    upvar 3 $contest_ contest

    ${_Self_} list_values_texts values texts $active $registrable
    
    switch [ llength $values ] {
	1	{
	    return <i>[ translate::sentence "No contest available" ]</i>
	}	
	2	 { 
	    set contest [ lindex $values 1 ]
	    return [ format \
		 {<input type="hidden" name="contest" value="%s"><b>%s</b>} \
		 [ lindex $values 1 ] [ lindex  $texts 1 ] ]	    
	}
	default  { 
	    if $update {
		return [ layout::menu contest $values $contest $texts 1 ] 
	    } else {
		return [ layout::menu contest $values $contest $texts 1 {} ] 
	    }
	}
    }

}


Operation Contests::list_values_texts {values_ texts_ 
    {active 1} {registrable 1}
} {
    upvar 3 $values_ values
    upvar 3 $texts_ texts
    
    set values {}
    set texts  {}

    
    lappend values  {}
    lappend texts	{}

    foreach cd [ glob -nocomplain -type d ${_Self_}/* ] {

	if [ catch { set seg [ data::open $cd ] } ] continue

	if { $active && [ $cd status {created concluded} ] } continue
	
	if { $registrable && ! [ $cd registrable ] } continue

	lappend texts [ set ${seg}::Designation ]
	lappend values [ file tail $cd ]
    }
}

Operation Contests::mining:data_to_file ? {
    global REL_BASE DIR_BASE URL_BASE
    variable DATA_FILE_NAME
    variable ::file::TMP

    set data_file "${_Self_}/submissions_data.txt"
    set prog_file "$TMP/data_miner.tcl"

    set fd [ open $prog_file "w" ]
    puts $fd [ format {
	lappend auto_path packages
	set REL_BASE %s
	set DIR_BASE %s
	set URL_BASE %s

	package require Contests
	Contests::mining_data %s
    } $REL_BASE $DIR_BASE $URL_BASE ${_Self_} ] 
    close $fd

    exec nice tclsh $prog_file > $data_file &

    template::load
    template::write
}


Operation Contests::mining:data_to_window ? {

    puts {<pre>}
    mining_data ${_Self_}
    puts {</pre>}
}


proc Contests::mining_data {dir} {

    data4mining::print_header 
    foreach dir [ glob -nocomplain $dir/*/submissions ] {
	data4mining::extract $dir 
    }

}


## Converts files in contests with Latin-1 encoding to UTF-8 
Operation Contests::convert:Latin-1->UFT-8 ? {

    convert_encoding ${_Self_} "ISO-8859" l1 utf-8
}

## Converts files in contests with UTF-8 encoding to Latin-1
Operation Contests::convert:Utf-8->latin-1 ? {

    convert_encoding ${_Self_} "UTF-8" utf-8 l1
}



## Converts files in $dir (and descendents) with $type $from encoding $to encoding
proc Contests::convert_encoding {dir type from to} {
    variable ::Session::Conf

    set no_errors 1

    if [ catch {
	set fd [ open "| find $dir -name *.tcl -exec file {{}} \;"  r ]
    } msg ] {
	puts <pre>$msg</pre>
	set no_errors 0
    }
    while { [ gets $fd line ] > -1 } {	
	set line [ split $line : ]
	if [ string equal [ string trim [ lindex [ lindex $line 1 ] 0 ] ] $type ] {
	    set file [ lindex $line 0 ]
	    puts $file
	    if [ catch { exec recode ${from}..${to} $file }  msg ] {
		puts <pre>$msg</pre>
		set no_errors 0
	    }
	}
    }
    if [ catch { close $fd  } msg ] {
	puts <pre>$msg</pre>
	set no_errors 0
    }

    if $no_errors {
	layout::window_close_after_waiting
    }
    layout::window_open $Conf(controller)?data+$dir select 0

}

## Returns contests capable of hadling a REST service
Operation Contests::service_handlers {} {

    set handlers {}
    foreach cd [ glob -nocomplain -type d ${_Self_}/* ] {
	if [ catch {  data::open $cd } ] continue

	if { [ $cd is_service ] && [ $cd status "running" ] } {	
	    lappend handlers $cd
	}
    }

    return $handlers
}

## Reads session criteria (or defaults), processes audit log and shows data
Operation Contests::audit:sessions ? {

    foreach {year month day} \
	[ clock format [ clock seconds ] -format "%Y %m %d" ] {}
    
    set year [ cgi::field year $year ]
    set month [ cgi::field month $month ]
    set day [ cgi::field day $day ]
    set profiles [ cgi::field profiles {team} ]
    set status [ cgi::field status {*} ]

    set date [ format "%s/%s/%s" $year $month $day ]

    process_audit_log $date $profiles $status data 

    show_audit_data ${_Self_} $year $month $day $profiles $status data
}


## Processes audit log for given date, profiles and status and sets data
proc Contests::process_audit_log {date profiles status data_} {
    upvar $data_ data

    set data(sessions) {}

    set fd [ open audit_log r ]

    while { [ gets $fd line ] > -1 } {
	if { ! [ regexp ^$date $line ] } continue

	foreach {date time session profile user command - - - - - -} $line {}

	switch -glob $profile $profiles {} default continue

	switch $command {
	    relogin - login { 
		set session_path data/configs/sessions/$session
		if [ file exists $session_path ] {
		    set data(status,$session) active
		    set sd [ data::open $session_path ]

		    set data(contest,$session) [ set ${sd}::contest ]
		} else {
		    set data(status,$session) concluded
		    set data(contest,$session) ""
		}
		switch -glob $data(status,$session) $status {} default continue
		lappend data(sessions) $session
		set data(login,$session) $time
		set data(user,$session) $user
		set data(last,$session) $time
		set data(profile,$session) $profile
	    }
	    default { 
		set data(last,$session) $time
	    }
	}
    }
    catch { close $fd }
    
}


## Presents session audit data on am HTML page with controls
proc Contests::show_audit_data {dir year month day profiles status data_} {
    upvar $data_ data

    set field [ cgi::field field "user" ]
    set order [ cgi::field order "down" ]

    foreach field_name { user profile login last status contest } {
	foreach order_name {up down} {
	    if { [ string equal $field $field_name ] &&
		 [ string equal $order $order_name ] 
	     } {
		set ${field_name}_${order_name} "sorted"
	    } else {		
		set ${field_name}_${order_name} ""	    
	    }
	}
    }

    set all_profiles { * admin judge team runner }
    set all_status { * active concluded}

    set year_menu [ layout::menu year [ enum [ expr $year-2 ] $year ] $year ]
    set month_menu [ layout::menu month [ enum 1 12 ] $month ]
    set day_menu [ layout::menu  day   [ enum 1 31 ] $day ]
		
    set profiles_menu [ layout::menu profiles $all_profiles $profiles ]
    set status_menu [ layout::menu status $all_status $status ]
    
    template::load Contests/audit_sessions.html
    set toggle 0


    set count [ llength $data(sessions) ]
    template::write head

    foreach  session [ lsort \
			   -command [list Contests::cmp data $field $order] \
			   $data(sessions) ] {
	layout::toggle_color toggle color
	template::write line
	
    }
    template::write foot

}


proc Contests::enum {a b {s 1}} {
    set enum {}
    for { set i $a } {$i <= $b} { incr i $s} { 
	lappend enum [ format "%02d" $i ]
    }
    return $enum
}


proc Contests::cmp {data_ field order a b} {
    upvar $data_ data

    switch $order   {
	up {
	    return [ string compare $data($field,$a) $data($field,$b) ]
	}
	down {
	    return [ string compare $data($field,$b) $data($field,$a) ]
	}
	default {
	    error "invalid order"
	}
	
    }
}