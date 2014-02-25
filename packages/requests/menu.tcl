#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: content.tcl
#
## Menus in content menu bar. Menus are implemented using HTML select elements
##
## TODO: accelerator keys for menu commands 

namespace eval menu {

    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {

	Save		"Save changes of current folder"
	Revert		"Revert form to saved values"
	Delete		"Delete folder content (and sub-folders)"
	Reset		"Reset class and content to default values"
	Unfreeze	"Reactivate folder again"
	Freeze		"Inactivate folder"
	Import...	"Import data from XML file"
	Export...	"Export data to XML file"
	Logout		"Logout from current session"
	
	Undo		"Undo changes using previously saved versions"
	Redo		"Redo changes using previously saved versions"
	Copy		"Copy folder (and sub-folders) to clipboard"
	Cut		"Cut folder (and sub-folders) to clipboard"
	Paste		"Past clipboard content in current folder"

    }
}

## show menu bar
proc menu::bar {dir class } {

    set menubar ""

    # standard menus
    standard_menus_data $dir menu
    foreach group {File Edit} {
	append menubar [ layout $group $menu($group) ]
    }
    # class menus
    set menus [ class_menus_data $dir $class menu ]
    foreach group $menus {
	if { [ info exists menu($group) ] && $menu($group) != {} } {
	    append menubar [ layout $group $menu($group) $class ]
	}
    }

    return $menubar 
}


## Standard menus common to all directories
## Menu data is a list of sequences of 3 elements: $command $label $active
proc menu::standard_menus_data {dir menu_} {
    variable ::Session::Conf
    upvar $menu_ menu

    set frozen		[ freezer::frozen $dir ]
    set melted		[ expr ! $frozen ]
    set frozeable	[ expr $melted && [ regexp \
			  {^data/(contests/\w.*|configs/\w+/\w+)$} $dir ] ]
    set pasteable	[ expr $melted && [ clipboard::can_paste $dir ] ]
    set undoable	[ backup::can_recover $dir ]
    set redoable	[ backup::can_recover $dir 1 ]
    set typed		[ file readable ${dir}/$::data::Class_file ]
    set portable	[ expr $typed && $melted ]
    set linkable 	[ expr $melted && [ clipboard::can_link $dir ] ]

    set menu(File) {}
    lappend menu(File) save				Save	  $melted      
    lappend menu(File) revert				Revert	  $melted	
    lappend menu(File) $Conf(controller)?cut+$dir	Delete	  1	
    lappend menu(File) $Conf(controller)?reset+$dir	Reset	  1
    lappend menu(File) $Conf(controller)?unfreeze+$dir	Unfreeze  $frozen
    lappend menu(File) $Conf(controller)?freeze+$dir	Freeze	  $frozeable
    lappend menu(File) $Conf(controller)?import+$dir	Import... $portable
    lappend menu(File) $Conf(controller)?export+$dir	Export... $portable
    lappend menu(File) $Conf(controller)?logout		Logout	  1
    
    
    set menu(Edit) {}
    lappend menu(Edit) $Conf(controller)?undo+$dir	Undo	$undoable
    lappend menu(Edit) $Conf(controller)?redo+$dir	Redo	$redoable
    lappend menu(Edit) $Conf(controller)?copy+$dir 	Copy	$melted	
    lappend menu(Edit) $Conf(controller)?cut+$dir 	Cut	1	
    lappend menu(Edit) $Conf(controller)?paste+$dir 	Paste	$pasteable
    lappend menu(Edit) $Conf(controller)?target+$dir 	Target	1
    lappend menu(Edit) $Conf(controller)?link+$dir 	Link	$linkable
}

## show menu bar
proc menu::config_bar {} {

    set menubar ""

    config_menus_data menu
    foreach group {Language Style} {
	append menubar [ layout $group $menu($group) ]
    }

    return $menubar
}


## Standard menus for configs
## Menu data is a list of sequences of 3 elements: $command $label $active
proc menu::config_menus_data {menu_} {
    variable ::Session::Conf
    upvar $menu_ menu


    foreach {name config items} {
	Language language	{
					en		English 
					pt		Portuguese
	    				es		Spanish
					ar		Arabic
	}
	Style	 style		{
					base		Standard
	    				grayscale 	Grayscale 	
	}
    } {
	set menu($name) {}	
	foreach {value label} $items {
	    if [ info exists Conf($config) ] {
		set active [ string compare $Conf($config) $value ]
	    } else {
		set active 0
	    }
	    lappend menu($name) \
		$Conf(controller)?config+$config+$value	$label $active
	}
    }

}

## Menu data generated from operations defined in classes with argument 
##		! 	simple command
##		?	command preceded by dialog
## Menu data is a list of sequences of 3 elements: $command $label $active
proc class_menus_data {dir class menu_} {
    variable ::data::Operations
    variable ::Session::Conf
    upvar $menu_ menu

    set menus [ string totitle [ translate::sentence $class ] ]
    if [ info exists Operations($class) ] {	
	foreach operation [ lsort $Operations($class) ] {	    
	    set mark [ string trim [ info args ${class}::${operation} ] ]
	    if { ! [ regexp {\?|\!} $mark ] } continue 
	    if  { [ regexp {(.*):(.*)} $operation - group name ] } {
		set group [ string totitle [ translate::sentence $group ] ]
		set label [ string totitle [ translate::sentence $name ] ]
	    } else {
		# the string totitle command does not work well with UTF-8
		set group [ translate::sentence $class ]
		set label [ string totitle [ translate::sentence $operation ] ]
	    }
	    set action $Conf(controller)?operation+$operation+$dir	    
	    if { [ string equal $mark ? ] } { append label ... }
	    if { [ lsearch $menus $group ] == -1 } { lappend menus $group } {}

	    if { [ namespace eval ::$class \
		       [ list info procs ${operation}_active ] ] != "" } {
		set active [ ::${class}::${operation}_active ]
	    } else {
		set active 1
	    }
	    lappend menu($group) $action $label $active
	}
    }

    return $menus
}


## Layout a menu using an HTML selector
## Operations are defined by command, label, on (boolean)
proc menu::layout {name operations {class menu}} {
    variable ::Session::Conf
    set html [ format \
		   {<select class="Menu" name="%s" onChange="execute(this)">} \
		   $name ]\n
    append html [ format \
		      {<option class="Button" value="">[ %s ]</option>} \
		      $name ]\n
    foreach {command label on} $operations {
	
	if [ info exists ${class}::Tip($label) ] {
	    set tip [ set ${class}::Tip($label) ]
	} else {
	    set tip ""
	}

	if $on {
	    append html \
		[format \
		     {<option title="%s" class="ItemOn" value="%s">%s</option>}\
		     $tip $command $label]\n
	} else {
	    append html [format \
			     {<option title="%s" class="ItemOff" value="">(%s)</option>} \
			     $tip $label]\n	    
	}
    }
    append html {</select>}
    return $html
}
