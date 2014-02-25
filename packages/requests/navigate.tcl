
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: navigate.tcl
#
## Navigation in the directory tree 
## 
##
## TODO: provide special navigation for large directories
## TODO: merge with help package

package provide navigate 1.0

package require data

namespace eval navigate {

    variable ActiveContestChanged 0 ;## Name says it all
    variable MaxLabelSize 17	;## Truncate larger directory/file names

    variable File 		;## Name of selected file
    variable Stretch	15	;## Pixels between levels
    variable N 		-1	;## Number of files processed
    variable S 		-1	;## Index of selected file
    # variable Conf		;## Configuration array
    variable Top_dirs 		;## List of dirs immediately bellow root

    set Top_dirs 		{ contests configs trash }

    # DEPRECATED
    array set Conf {
	words		{}
	flow		down
	scope		label
    }	

}

## Processes CGI state, copying CGI variables to Cong and cookies
## DEPRECATED
proc navigate::state {} {
    variable ::Session::Conf

    cgi::recover_cookies Conf

    foreach var [ array names Conf ] {
	if { 
	    [ info exists cgi::Field($var) ] && 
	    $cgi::Field($var) != ""
	} {
	    set Conf($var) $cgi::Field($var)
	} 
    } 

    cgi::record_cookies Conf
}

## Processing cookies: setting Contest through navigation
proc navigate::_state_ {} {
    variable ActiveContestChanged
    variable ::Session::Conf
    global argv

    if {
	[ regexp {^data data/contests/([^/]+)/? } $argv - contest  ]	&&
	[ file isdirectory data/contests/$contest ]
    } {
	if {
	    [ string equal [ data::class data/contests/$contest ] Contest ] &&
	    [ file readable data/contests/$contest/$::data::Data_file ]
	} {
	    set Conf(contest) $contest
	} else {
	    set Conf(contest) ""
	}
	set ActiveContestChanged 1
    } elseif [ regexp {^data data/(\w+)/? } $argv ] {
	set Conf(contest) ""
	set ActiveContestChanged 1	
    }

}

## Show left frame (data) 
## WARNING: This is a UNSAFE command 
proc navigate::data args {

    set dir [ set part "" ]

    foreach {dir part update} $args {}

    switch $part {
	header	{ navigate::show_header	$dir }
	tree	{ navigate::show_tree	$dir }
	footer	{ navigate::show_footer	$dir }
	search  { navigate::show_data	$dir }
	default { 
	    set ::Session::Conf(words) ""
	    navigate::show_data	$dir 
	}
    }
}

## Format a directory tree (creates 3 frames)
proc navigate::show_data {dir} {
    global env

    # set base dir if none was provided
    if { $dir == "" } { 
	variable ::Session::Conf
	if { ! [ string equal $Conf(contest) "" ] } {
	    set dir data/contests/$Conf(contest)
	} else {
	    variable ::data::Base 
	    set dir $Base 
	}
    }
    set dir [ search $dir ]

    # this directory is being displayed: mark it with a trailing slash /
    if { [ info exists env(HTTP_REFERER) ] &&
	 [ regexp [ format {\?%s\+} $dir ] $env(HTTP_REFERER) ]
     } {	
	append dir /
    }

    template::load data.html

    template::write frameset
}


## Format header of directory tree
proc navigate::show_header  {dir} {
    variable ::Session::Conf
    variable ::data::Base 
    variable ::Session::Conf
    variable ActiveContestChanged

    if { $dir == "" } { set dir $Base }

    check_dirs
    
    # directories marked with a trailing slask don't need to be loaded
    if [ regexp {/$} $dir ] {
	set load ""
    } else {
	set load [ format {window.open('%s?content+%s','work');} \
		       $Conf(controller) $dir ]
    }
    if $ActiveContestChanged  {
	append load { window.open('?banner','banner');}
    }

    template::load data.html
    set help_button [ layout::help_button interfaces ]
    if { $Conf(contest) == ""} {
	template::write header_admin
    } else {
	template::write header_admin_judge
    }
}

## Format footer of directory tree
proc navigate::show_footer  {dir} {
    variable ::Session::Conf

    template::load data.html

    set words $Conf(words)
    switch $Conf(flow) {
	up	{ set check_up "checked"	; set check_down ""	   }
	down	{ set check_up ""		; set check_down "checked" }
    }
    switch $Conf(scope) {
	label	{ set check_label "checked"	; set check_content ""	   }
	content	{ set check_label ""		; set check_content "checked" }
    }

    template::write footer
}


proc navigate::format_search_commands {dir} {
    set commands ""
    
    append commands [ template::formatting search ]
}

## Check toplevel directories and created then if needed
proc navigate::check_dirs {} {
    variable Top_dirs
    variable ::data::Base

    foreach top $Top_dirs { 
	if { ! [ file isdirectory $Base/$top ] } {
	    data::new $Base/$top [ string totitle $top ]
	    file attributes $Base/$top -permissions g+w
	}
    }
}

## Formats the directory tree 
proc navigate::show_tree {dir} {
    variable ::data::Base

    template::load data.html

    set depth [ llength [ split $Base / ] ]
    set path  [ lrange [ split $dir / ] $depth end ]   

    template::write tree_header
    transverse_tree $Base $path
    template::write tree_footer
}

## Unfolds recursively a tree directory
proc navigate::transverse_tree {cur path} {
    variable Index 
    variable Stretch
    variable File 
    variable N 
    variable S

    set dir  [ lindex $path 0 ]
    set rest [ lrange $path 1 end ]

    if { [ string compare $dir . ] == 0 } { 
	list $cur $rest
	return
    }

    set tab [ expr [ llength [ split $cur / ] ] * $Stretch ]

    foreach {d n} [ index $cur ] {
	if { ! [  file readable $cur/$d ] } {
	    template::write unreadable
	    continue
	}
	set File([incr N]) $cur/$d
	
	switch [ type $cur/$d ] {
	    directory {	 show_directory	$cur $path $dir $rest $tab $d $n }
	    default   {	 show_file	$cur $path $dir $rest $tab $d $n }

	}
    }   

}

## Show (and expand) a directory
proc navigate::show_directory {cur path dir rest tab d n} {
    variable ::Session::Conf
    variable MaxLabelSize
    variable N 
    variable S

    if { [ string compare $dir $d ] == 0 } {
	set S $N
	set uri $Conf(controller)?data+$cur
	if { [ llength $rest ] > 0 } {
	    append uri /$d
	}
	if { [ llength $rest ] == 0 } {
	    # append uri /$d	;# refresh	open folder
	    append uri "" 	;# close	open folder
	    template::write selected
	    set icon  folder.open.red.png

	} else {
	    set icon  folder.open.png
	}
	set color \#CC0000
	
    } else {
	set uri $Conf(controller)?data+$cur/$d
	set color black
	set icon  folder.png

    }
    
    if { [ string compare [ file type $cur/$d ] link ] == 0 } {
	set icon back.png
    }


    # Without special icons for selected folders
    set class [ data::class $cur/$d ]
    if [ file readable public_html/icons/$class.png ] {
	set icon  $class.png
    }


    # uses bit g+w of directory to decide if translates
    if { [ expr [ file attributes $cur/$d -permissions ] & 0010 ] } {
	set text [ translate::sentence $n ]
    } else {
	set text $n
    }

    if { [ string length $n ] > $MaxLabelSize } { 
	set n [ string range $n 0 [ expr $MaxLabelSize-3 ] ]... 
    }
    template::write directory

    if { [ string compare $dir $d ] == 0 } {
	transverse_tree $cur/$d $rest 
    }
}

## Show a file
proc navigate::show_file {cur path dir rest tab d n} {
    variable ::Session::Conf
    variable MaxLabelSize
    variable Tree
    variable N 
    variable S


    switch [ lindex [ split [ email::mime $d ] / ] 0 ] {

	application { set uri $Conf(controller)/$cur/$d }
	default { set uri $Conf(controller)?data+$cur/$d }
    }


    if { [ file executable $cur/$d ] } {
	set icon script.png
    } elseif { [ freezer::frozen $cur/$d ] } {
	set icon folder.sec.png
    } elseif { [ string compare [ file type $cur/$d ] link ] == 0 } {
	set icon link.png
    } else {
	set icon generic.png
    }
    
    if { [ string compare $dir $d ] == 0 } {
	set S $N
	set style u
	set color red

	regsub {(.*)\.(png)$} $icon {\1.red.\2} icon
	template::write selected
    } else {
	set style i
	set color black
    }
    if { [ string length $n ] > $MaxLabelSize } { 
	set n [ string range $n 0 [ expr $MaxLabelSize-3 ] ]... 
    }
    template::write file
}



## Returns the indice of a directory
proc navigate::index {dir} {

    if { [ file readable $dir/index.txt ] } {
	return [ index.txt $dir ]
    }
    
    if { [ file readable $dir/index.html ] } {
	return [ index.html $dir ]
    }
    return [ index.ls $dir ]
}

## Generates an index from the content of a directory
proc navigate::index.ls {dir} {

    set index {} 
    foreach d [ lsort [ glob -nocomplain $dir/* ] ] {
	set d [ file tail $d ]
	lappend index $d $d
    }
    return $index
}


## Reads and index in txt format (not in use)
proc navigate::index.txt {dir} {
    
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

## Reads an index in HTML format (not in use)
proc navigate::index.html {dir} {
    set html ""
    set fd [ open $dir/index.html ]
    while { [ gets $fd line ] > -1 } {
	append html $line\n
    }
    catch { close $fd }

    set index {} 
    set pat {<a ([^>]*)>([^<]*)</a>} 
    while { [ regexp -nocase $pat $html - args n ] } {
	if [ regexp -nocase {href="([^\"]*)"} $args - d ] { 
	    lappend index[ string trim $d ] $n
	}
	regsub -nocase $pat $html {} html
    }
    return $index
}

## Returns a type dereferencing symbolic links
proc navigate::type {file} {

    return [ file type [ file::deref_link $file ] ]
}

## Search the next/previous  directory named/containing words 
proc navigate::search {dir} {
    variable ::Session::Conf

    if { $Conf(words) == "" } { 
	return $dir 
    } else {
	# build a regular expression matching words
	regsub -all { } [ string trim $Conf(words) ] {.*} re
    }

    switch $Conf(flow) {
	up {
	    return [ search_up $dir $re  ]
	}
	down {

	    if { [ set found [ search_down $dir $re ] ] != {} } {
		return $found
	    } else {
		return [ search_up $dir $re  ]
	    }
	}
    }

    return $dir
}

## Search up (left/right) the directory tree
proc navigate::search_up {dir re} {
    variable ::Session::Conf

    if [ string equal [ set par [ file dirname $dir ] ] "." ] {
	return {}
    }
    set ls [ lsort [ glob -nocomplain $par/* ] ]
    set pos [ lsearch $ls $dir ]

    switch $Conf(flow) {
	up	{ set ls [ reverse [ lrange $ls 0 [ expr $pos-1 ] ] ] }
	down	{ set ls [ 	     lrange $ls [ expr $pos+1 ] end ] }
    }

    if { [ set found [ search_ls $ls $re ] ] != {} } {
	return $found 
    } else {
	return [ search_up $par $re  ] 
    }

}

## Search down the directory tree
proc navigate::search_down {dir re} {
    variable ::Session::Conf
    variable ::data::Class

    set ls [ lsort [ glob -nocomplain $dir/* ] ]
    if [ string equal $Conf(flow) up ] { set ls [ reverse $ls ] }

    return [ search_ls $ls $re ]
}

## search a list of files/directories and its descendants
proc navigate::search_ls {ls re} {
    variable ::Session::Conf 
    variable ::data::Attributes
    variable ::data::Class

    foreach f $ls {
	switch $Conf(scope) {
	    "label" {
		if [ regexp $re [ file tail $f ] ] { return $f }
		if {
		    [ string equal [ file type $f ] "directory" ]	&& 
		    [ set found [ search_down $f $re ] ] != {} 
		} {
		    return $found
		}
	    }
	    "content" {
		switch [ file type $f ] {
		    "file"	{
			catch {  exec grep -c -r $re $f  } output
			set count [ lindex $output 0 ]
			if { $count > 0 } { return $f }
		    }
		    "directory" {
			if [ catch { set seg [ data::open $f ] } ] continue
			foreach  {var type comp}  $Attributes($Class($f)) {
			    if [ catch { set value [ set ${seg}::$var ] } ] {
				continue
			    }
			    if [ regexp $re $value ] { return $f }
			}
			data::close $f
			if { [ set found [ search_down $f $re ] ] != {} } {
			    return $found
			}
		    }
		}
	    }
	}
    }
    # not found
    return {}
}


## Reverse the order of the elements in a list
proc navigate::reverse {ls} {

    set n {}
    foreach e $ls { 
	set n [ concat $e $n ]
    }
    return $n
}

