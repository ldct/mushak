#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Problems.tcl
# 
## Set of problems in a contest
##

package provide Problems 1.0

package require data

namespace eval Problems {
    variable Index	index.xml	;# index filename
    variable Archive	problems.tgz	;# archive filename
    variable ListItens	3		;# number of items in problem list

    variable Tip

    array names Tip {
	Presents	"Type of selector to present problems"
	Problem		"Problem folder"
    }

}


Attributes Problems {

    Fatal	fatal	{}
    Warning	warning {}        

    Presents	menu	{radio menu list text}
    Problem	dirs	Problem
}

## Search problem by name
Operation Problems::search {name {by Name} } {

    set name [ string trim $name ]
    foreach problem [ glob -type d -nocomplain ${_Self_}/* ] {

	set sg [ data::open $problem ]
	if {
	    [ info exists ${sg}::${by} ] &&
	    [ string equal [ string trim [ set ${sg}::${by} ] ] $name ] }  {
	    return $problem
	}
    }
    return {}
}

Operation Problems::_update_ {} {

    check::reset Fatal Warning

    switch [ check::dirs Fatal ${_Self_} ] {
	0 {	    check::record Fatal   simple "No problems defined"	    }
	1 {	    check::record Warning simple "Just one problem defined" }
    }

    return [ check::requires_propagation $Fatal ]


}

## Propagate recursivelly checks to sub-directories.
Operation Problems::check {} {

    check::dir_start 1
    switch [ check::sub_dirs ] {
	0	{ check::report_error Fatal	"No problem defined"    }
	1	{ check::report_error Warning	"Just one problem defined" }
	default {}
    }
    check::dir_end 1
}

## Returns a selector for choosing the problem; the selector type is
## either defined in attribute Presents or choosen in function the 
## number of problems.
Operation Problems::selector {} {

    if { $Presents == "" } {
	set np [ llength [ glob -nocomplain -type d ${_Self_}/* ] ]
	if { $np < 2  } {	set presents label	    
	} elseif { $np < 10 } { set presents radio 
	} elseif { $np < 20 } { set presents menu
	} elseif { $np < 30 } { set presents list
	} else		      { set presents text }
    } else {
	set presents $Presents
    }
    
    return [ ${_Self_} selector_$presents ]
}

# Generates HTML for a problem selector using hidden field.
Operation Problems::selector_label {} {

    set id [ lindex [ ${_Self_} problems ] 0 ]
    set prob [ data::open ${_Self_}/$id ]
    set_problem_vars ${_Self_} $id	
    
    if { $title == "" } {
	set descr $name 
    } else {
	set descr $title
    }

    set problem ""
    set frmt {<input type="hidden" title="%s - %s" name="problem" value="%s">}
    append problem [ format $frmt $name $title $id ]
    append problem [ format {%s} $descr ]

    return $problem
}

# Generates HTML for a problem selector using radio buttons.
Operation Problems::selector_radio {} {

    set checked "checked"
    set problems ""
    foreach p [ lsort [ ${_Self_} problems ] ] { 
	set_problem_vars ${_Self_} $p	
	append problems \n
	append problems [ format {<input %s text="%s" } $checked $name ] 
	append problems [ format {type="radio" name="problem" } ]
	append problems [ format {value="%s" title="%s - %s" } $p $name $title]
	append problems [ format {style="background: %s;" } $color ]
	append problems [ format {onClick="this.form.view.click();">} ]
	append problems [ format {%s &nbsp;&nbsp;} $name ]
	set checked ""
	
    }

    return $problems
}

## Generates HTML for a problem selector using a list of items.
Operation Problems::selector_list {} { 
    variable ListItens

    return [ ${_Self_} selector_menu $ListItens ]
}

## Generates HTML for a problem selector using a pull-down menu.
Operation Problems::selector_menu {{n 0}} {

    set s " selected"
    set problems [ format {<select name="problem" size="%d"} $n ]
    append problems { onChange="this.form.view.click();">}

    foreach p [ lsort [ ${_Self_} problems ] ] { 
	set_problem_vars ${_Self_} $p	
	append problems [format {<option value="%s"%s>%s - %s</option>} \
			      $p $s $name $title]
	set s ""
    }
    append problems {</select>}
    return $problems
}

## Generates HTML for a problem selector using a text entry.
Operation Problems::selector_text {} {
    return {<input name="problem" onChange="this.form.view.click();">}
}

## Returns the list of currently defined problems, optionally sorted
Operation Problems::problems { {sorted 0 } } {

    set problems {}
    foreach prob [ glob -type d -nocomplain ${_Self_}/* ] {
	set pid [ file tail $prob ]
	lappend problems $pid
	if $sorted {
	    set prb [ data::open $prob ]
	    set name($pid) [ set ${prb}::Name ]
	}
    }

    if $sorted {

	proc cmp {a b} {
	    upvar 2 name name	    
	    return [ string compare $name($a) $name($b) ]
	}

	set problems [ lsort -command [ namespace code cmp ] $problems ]
    }

    return $problems
}

## Import problem from remote repository (other Mooshak acting as service)
Operation Problems::import:remote ? {
    global REL_BASE
    
    set dir ${_Self_} 
 
    set selector {}

    template::load
    template::write 

}

Operation Problems::importing_remote args {
    variable ::Session::Conf
    variable ::file::TMP

    set dir ${_Self_} 

    set url  [ cgi::field URL "" ]

##    $dir create_problem_from_url $url

    switch [ set content_type [ remote_request $url content ] ] {
	text/xml {

	    parse_data values names

	    set selector [ layout::menu URL $values {} $names ]

	    template::load Problems/import:remote
	    template::write 
	}

	default { 
	    set archive [save_content_as_file $dir $url $content $content_type] 
	    create_remote_probleam_from_file $dir $archive $url

	    layout::window_open $Conf(controller)?data+$dir select
	    layout::window_close
	}

    }
}

## Dowload problem from remote URL and create a folder for it
Operation Problems::create_problem_from_url {url} {

    set dir ${_Self_}

    set content_type [ remote_request $url content ]

    set archive [ save_content_as_file $dir $url $content $content_type ] 

    return [ create_remote_problem_from_file $dir $archive $url ]

}
 


proc Problems::remote_request {url content_} {

    package require http
    upvar #0 [ ::http::geturl $url ] state
    upvar $content_ content 

    set content $state(body) 
    array set meta $state(meta)

    return $meta(Content-Type)
}


proc Problems::save_content_as_file {dir url content content_type} {
    global DIR_BASE

    set name [ file tail $url ]
    set extension [ email::extension_from_mime $content_type ]
    set archive $DIR_BASE/$dir/$name$extension

    set fd [ ::open $archive "w" ]
    puts $fd $content 
    catch { close $fd } msg    

    return $archive

}

proc Problems::create_remote_problem_from_file {dir archive url} {

    set problem_dir [ new_name $dir ]
    data::new $problem_dir Problem 
    data::write $problem_dir

    content::import_file $problem_dir $archive

    set pdir [ data::open $problem_dir ]
    set ${pdir}::Original_location $url
    set ${pdir}::Name [ file tail $problem_dir ] 
    data::write $problem_dir

    return $problem_dir
}


## Generates new folder name for a remote problem
proc Problems::new_name {dir} {

    set prefix R
    set count  [ llength [ glob -nocomplain $dir/${prefix}* ] ]
    incr count
    set attempts 10

    while { [ incr attempts -1 ] > 0 } {
	set filename [ format {%s%d} $dir/$prefix $count ]
	if { ! [ file exists $filename ] } {
	    return $filename
	}
	incr count 
    }
    return {}
}

## For given $prob in $dir defines variables name and color in calling prog
proc Problems::set_problem_vars {dir prob} {

    set prob [ data::open $dir/$prob ]	

    foreach {var att def} {name Name ? color Color white title Title ?} {
	upvar $var $var
	if [ info exists ${prob}::${att} ] {
	    set $var [ set ${prob}::${att} ]
	} else {
	    set $var $def
	}
    }   
}
