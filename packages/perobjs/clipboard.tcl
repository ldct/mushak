#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@dcc.fc.up.pt
#
#-----------------------------------------------------------------------------
# file: clipboard.tcl
# 
## Basic clipboard functions - cut copy and past - over directories (and files)
## Paste is only possible in directories with same type (can_paste).
## Name and type can be retrived using procedures with that name.
##
## By default, copy and paste update content window.
##
## Updated to create symbolic links

package provide clipboard 1.0

namespace eval clipboard {
    variable Clip_dir	clipboard	;# clipboard directory

    namespace export cut		;# cuts selected directory or file
    namespace export copy		;# copies selected directory or file
    namespace export paste		;# pastes selected directory or file
    namespace export can_paste 		;# can paste selected directory/file?
    namespace export name		;# name of dir in clipboard
    namespace export type		;# type of dir in clipboard

    namespace export target		;# set current dir as target
    namespace export link		;# link current dir to current target
}

## Set that source of a link
proc clipboard::target {path {update 1}} {
    variable ::Session::Conf

    set Conf(target) $path

    if $update {
	content::show $path 1
    }
}

## Checks if can be linked
proc clipboard::can_link {path} {
    variable ::Session::Conf

    if { ! [ file exists $path ] || ! [ file exists $Conf(target) ] } {
	return false 
    }

    ## avoid circular links
    if { [ string equal 				\
	       [ file::deref_link $path ] 		\
	       [ file::deref_link $Conf(target) ] ] 	\
     } {
	return false
    }

    return [ string equal [ data::class $Conf(target) ] [ data::class $path ] ]
}

## Complets the link
proc clipboard::link {path {update 1}} {
    variable ::Session::Conf

    if { [ can_link $path ] } {

	file delete -force -- $path
    
	set here [ pwd ]
	set name [ file tail $path ]
	set dir  [ file dirname $path ] 

	set source_path [ split $path 		/ ]
	set target_path [ split $Conf(target)	/ ]

	while { [ string equal 				\
		      [ lindex $source_path 0 ] 	\
		      [ lindex $target_path 0 ] ] } {

	    set source_path [ lreplace $source_path 0 0 ]
	    set target_path [ lreplace $target_path 0 0 ]
	}
	
	set back [ string repeat ../ [ expr [ llength $source_path ] - 1 ] ]
	set target $back[ join $target_path / ]

	cd $dir
	file link -symbolic $name $target     
	cd $here
    }

    if $update {
	content::show $path 1
    }
}

## Cuts selected directory or file
proc clipboard::cut {path {update 1}} {
    variable Clip_dir

    if [ file isdirectory $path ] {
	# if it is an object let it be properly destroyed
	data::open $path
	data::destroy $path
    }
    if { [ string compare [ file type $path ] "link" ] == 0 } {
	file delete -force -- $path
    } else {
	file::move $path $Clip_dir
    }

    if $update {
	content::show [ file dirname $path ] 1
    }
}

## Copies selected directory or file
proc clipboard::copy {path {update 1}} {
    variable Clip_dir

    # keep the clipboard clean
    foreach content [ glob -nocomplain $Clip_dir/* ] {
	file delete -force -- $content
    }

    # copy the original file rther than the link
    set path [ file::deref_link $path ]

    file::move $path $Clip_dir 1

    if $update {
	content::show $path 1
    }
}

## DEPRECATED
## Links (symbolicaly) selected directory or file
# proc clipboard::link {path {update 1}} {
#     variable Clip_dir

#     # keep the clipboard clean
#     foreach content [ glob -nocomplain $Clip_dir/* ] {
# 	file delete -force -- $content
#     }

#     file::move $path $Clip_dir 1

#     if $update {
# 	content::show $path 1
#     }
# }


## Return on clipboard name
proc clipboard::name {} {

    if { [ set dir  [ clip ] ] == {} } {
	return {}
    } else {
	return [ file tail $dir ]
    }

}

## Return on clipboard type
proc clipboard::type {} {
    
    if { [ set dir  [ clip ] ] == {} } {
	return {}
    } else {
	return [ data::class $dir ]
    }
    
}

## Last directory in clipboard 
proc clipboard::clip {} {
    variable Clip_dir

    return [ lindex [ lsort -command clipboard::cmp_fx \
	    [ glob -nocomplain $Clip_dir/*  ] ] 0 ]
}

## Compares files using modification time
proc clipboard::cmp_fx {a b} {
    return [ expr [ file mtime $b ] - [ file mtime $a ] ]
}

## Can paste selected directory/file?
proc clipboard::can_paste {dir} {

    return [ string equal [ data::class [ clip ] ] [ data::class $dir ] ]

}


## Pastes selected directory or file
proc clipboard::paste {dir {update 1}} {
    
    if [ can_paste $dir ] {
	catch { eval file delete -force -- [ glob $dir/* ] }
	catch { eval file delete -force -- [ glob $dir/.\[a-zA-Z\]* ] }
	catch { eval file copy -force -- [ glob  [ clip ]/* ] $dir }
	catch { eval file copy -force -- [ glob [ clip ]/.\[a-zA-Z\]* ] $dir }
    }

    if $update { 
	content::show $dir 1
    }
}
