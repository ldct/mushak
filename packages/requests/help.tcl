#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#------------------------------------------------------------------------------
# file: help.tcl
#
## Navigation on a directory structure containing help files.
## Includes structural navigation and free text search.
## This package dependes on the following session configuration fields:
##
##	Conf	Default	Value	Meaning
##	--------------------------------------------------------
##	size	0	int	text size (used in font tags)
##	tab	1	bool	show left tab?
##	tree	0	bool	expand tree?
##	search  0	bool	currently searching?
##	path	""	string	
##	words	""	string	search term (set of words)
##
##
##
## TODO: Merge this package with ´navigate´
##


package provide help 1.0

namespace eval help {

    variable Base public_html/help	;# directory with help files
    variable Rel_base /			;# URI base
    variable File 			;# name of files in menu
    variable N -1			;# number of processed files
    variable S 0			;# index of selected file
    variable Max_depth 3		;# max depth in expandion

}



## Generates  HTML formated help page 
## based session configuration and args
proc help::help args {
    variable ::Session::Conf 
    variable ::cgi::Field
    variable Base
    variable Rel_base
    global argv

    # updade session configuration
    foreach { - Conf(path) Conf(command)} $argv {}
    switch $Conf(command) {
	expand		{ set Conf(tab)	   1 }
	collapse	{ set Conf(tab)    0 }
	fold		{ set Conf(tree)   0 }
	unfold		{ set Conf(tree)   1 }
	enlarge		{ incr Conf(size)  1 }
	reduce		{ incr Conf(size) -1 }

    }    

    ## avoid directory tranversal atacks 
    while { [ regsub {[^/.+]+/\.\./} $Conf(path) {} Conf(path) ] } {} 
    if [ regexp {\.\./} $Conf(path) ] { set Conf(path) {} }

    if { [ info exists Field(words) ] } {
	set Conf(words) $Field(words)
    }
    if { ! [ info exists Conf(words) ] } {
	set Conf(words) ""    
    }    

    #set Conf(search) [ expr $Conf(words) == "" ]
    if { $Conf(path) != "" || $Conf(words) == "" } { 
	set Conf(search) 0 
    } { 
	set Conf(search) 1 
    }

    # generates html page
    template::load help
    set curr [ menu menu_layout ]
    if  $Conf(search) {
	search page_layout
    } else {
	page page_layout
    }

    template::write layout
}


## Returns a directory index
proc help::index {dir} {

    if { [ file readable $dir/index.txt ] } {
	return [ index.txt $dir ]
    }
    
    if { [ file readable $dir/index.html ] } {
	return [ index.html $dir ]
    }
    return {}
}

## Reads an index in text format 
proc  help::index.txt {dir} {
    
    set index {} 
    set fd [ open $dir/index.txt ]
    while { [ gets $fd line ] > -1 } {
	if { [ set line [ string trim $line ] ] == "" } continue
	if { [ string compare [ string index $line 0 ] "#" ] == 0 } continue 
	set d [ lindex $line 0 ]
	if { [ llength $line ] == 1 } {
	    set n $d 
	} else {
	    set n [ lrange $line 1 end ]
	}
	lappend index$d $n
    }
    catch { close $fd }
    return $index
}

## Reads an index in HTML format
proc  help::index.html {dir} {

    set html ""
    set fd [ open $dir/index.html ]
    while { [ gets $fd line ] > -1 } {
	append html $line\n
    }
    catch { close $fd }
    set index {} 
    set pat {<a.*?href="(?!(http://|/))(.*?)"[^>]*>(.*?)</a>}
    while { [ regexp -nocase $pat $html - d n ] } {
	lappend index [ string trim $d ] $n
	regsub -nocase $pat $html {} html
    }
    return $index
}

## Returns a type after dereferencing symbolic links
proc help::type {file} {

    set type [ file type $file ]
    while { [ string compare $type link ] == 0 } {
	set file [ file readlink $file ]
	set type [ file type $file ]
    }
    return $type
}

## navigation 
proc help::tree {cur path} {
    variable Index 
    variable File 
    variable N 
    variable S

    set prog [ prog ]
    set dir  [ lindex $path 0 ]
    set rest [ lrange $path 1 end ]

    if { [ string compare $dir . ] == 0 } { 
	tree $cur $rest
	return
    }

    template::record menu_cab

    foreach {d n} [ index $cur ] {
	if { ! [  file readable $cur/$d ] } {
	    template::record menu_off
	    continue
	}
	set File([incr N]) $cur/$d

	switch [ type $cur/$d ] {
	    directory {
		if { [ string compare $dir $d ] == 0 } {
		    set S $N
		    set uri $prog?help+$cur
		} else {
		    set uri $prog?help+$cur/$d
		}

		if { [ string compare $dir $d ] == 0 } {
		    if { [ llength $rest ] == 0 } {
			template::record menu_sel
		    } else {
			template::record menu_dir
		    }
		    tree $cur/$d $rest 
		} else {
		    template::record menu_dir
		}

	    }
	    default {
		set uri $prog?help+$cur/$d

		if { [ string compare $dir $d ] == 0 } {
		    set S $N
		    template::record menu_sel
		} else {
		    template::record menu_file
		}
	    }
	}
    }
    template::record menu_rod

}

## Formats a menu by expanding a tree
proc help::menu {menu_} {
    variable Base
    variable ::Session::Conf
    variable File
    variable N
    variable S
    
    upvar $menu_ menu

    set prog [ prog ]

    set here [ pwd ]
    cd $Base
    set File([incr N]) $Conf(path)
    tree . [ split $Conf(path) / ] 
    cd $here

    set curr ""	; catch { set curr $File($S) } 
    set next ""	; catch { set next $File([ expr $S + 1 ]) }
    set prev ""	; catch { set prev $File([ expr $S - 1 ]) }

    if $Conf(tab) {
	
	set bar [ bar $curr $prev $next ]

	set menu ""
	append menu [ template::formatting menu_head ]
	append menu [ template::restore ] 
	append menu [ template::formatting menu_foot ] 
	
	return $curr
    } else {

	set bar [ bar $curr $prev $next ]
	set menu [ template::formatting menu_collapsed ]

	return $Conf(path)
    }
    
}

## Formats command bar
proc help::bar {curr prev next} {
    variable ::Session::Conf

    set prog [ prog ]
    if $Conf(tab) {
	set tab_text { |  }
	set tab_command collapse
    } else {
	set tab_text { || }
	set tab_command expand
    }

    if $Conf(tree) {
	set fold_text { . }
	set fold_command fold
    } else {
	set fold_text { * }
	set fold_command unfold
    }

    return [ template::formatting bar ]
}


## Write an help page
proc help::page {page_} {
    variable ::Session::Conf
    upvar $page_ page


    set page [ template::formatting page_head ]

    set core [ format {<font size="%+d">} $Conf(size) ]
    append core	[ content $Conf(path) ]

    regsub -all -nocase {<t[dh].*?>} $core \
	    [ format {\0<font size="%+d">} $Conf(size) ] core
    
    append page $core    

    append page [ template::formatting page_foot ]    

}

## Returns the content of a page
proc help::content {path {depth 0}} {
    variable Base
    variable Rel_base
    variable Max_depth
    variable ::Session::Conf

    set prog [ prog ]
    set fx $Base/$path

    if [ file isdirectory $fx ] {
	set fx $fx/index.html
	if [ regexp $path {/$} ] {
	    append path /
	}
	set dir $path
    } else {
	set dir [ file dirname $path ]
    }

    if [ file readable $fx ] {

	set fd [ open $fx r ]
	set html [ file::read_in $fx ]
	catch { close $fd }
	

	if { $Conf(tree) && [ incr depth ] < $Max_depth } {
	    if { [ file isdirectory $fx ] || [ regexp {index.html$} $fx ]  } {
		# uses directory index
		set pat {<a.*?href="%s">.*?</a>}
		foreach {d n} [ index $Base/$dir ]  {
		    regsub -nocase [ format $pat $d ] $html $n html
		    append html [ content $dir/$d $depth ]
		}
	    } else {		
		# selects only relative URLS in file
		set patt {<a.*?href="(?!(http://|/))(.*?)">(.*?)</a>}
		while { [ regexp -nocase  $patt $html - rel title] } {
		    set sub $dir/$rel
		    regsub -nocase $patt $html $title html
		    append html [ content $sub ]
		}
	    }
	} else {
	    regsub -all -nocase {(<a.*?href=\")(?!(http://|/))(.*?\")} $html \
		"\\1$Conf(controller)?help+$dir/\\2" html
	}

	# replace relative URL in SRC (images)
	regsub -all -nocase {( src=")(?!(http://|/))(.*?")} $html \
		"\\1../../help/$dir/\\2" html

	
	# tag serached words
	foreach word $Conf(words) {
	    regsub -all -nocase [ format {(%s)(?!([^<]*>))} $word ] $html \
		{<span id="Found">\1</span>} html
	}
	
    } else {
	set html [ format {<div id="Error">cannot open %s</div>} $path ]
    }   
 
    return $html
}

## Formats search
proc help::search {search_} {
    variable ::Session::Conf
    upvar $search_ search 

    set prog [ prog ]
    set search [ template::formatting search_head ]
    set n 0
    foreach trio [ lsort -index 0 -decreasing [ found $Conf(words) ] ] {
	foreach {count title file} $trio {}
	append search [ template::formatting search_found ]
	incr n
    }
    append search [ template::formatting search_foot ]
}

## Searches in HTML files with content
proc help::found {words} {
    variable Base

    set hits {}
    set files [ glob -nocomplain $Base/* ] 
    while { $files != "" } {
	set file  [ lindex $files 0 ]
	set files [ lrange $files 1 end ]
	
	switch [ file type $file ] {
	    directory {
		set files [ concat $files [ glob -nocomplain $file/* ] ]
	    }
	    file {
		if { ! [ regexp {.*\.html$} $file ] } continue 

		set html [ file::read_in $file ]
		set c 0
		foreach word $words {
		    incr c [ regsub -all $word $html {\0} html ]
		}
		if { $c > 0 } { 
		    regexp -nocase {<h[0-9]>(.*?)</h[0-9]>} $html - title
		    regexp {public_html/help/(.*)$} $file - file
		    lappend hits [ list $c $title $file ]
		}
	    }
	}
    }
    return $hits
}

## This program name
proc help::prog {} {
    variable ::Session::Conf

    #regexp {/?([^/]*)$} [ info script ] - prog
    #return $prog

    return $Conf(controller)
}

