#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: utils.tcl
# 
## File utilities

package provide file 1.0

namespace eval file {

    namespace export inode 		;## Return inode of filename
    namespace export with_inode 	;## Returns file from list with inode
    namespace export canonical_pathname ;## Return absolute direct pathname
    namespace export read_in		;## Returns text file content
    namespace export my_chmod		;## Chmod in given dir
    namespace export move		;## Move file or directory
    namespace export deref_link		;## Deref chain of symbolic links
    namespace export expand		;## Expand variables in a command line
    namespace export permissions	;## Set given permissions in args
    namespace export recode		;## r. characters for plataform
    namespace export newer		;## file f newer than g
    namespace export lock		;## Create a lockfile
    namespace export unlock		;## Remove lockfile created lock
    namespace export archive_command	;## Command line prefix for archiving
    namespace export unarchive_command  ;## Command line prefix for unarchiving

    variable FILE /usr/bin/file		;## Unix file type command
    variable TMP_BASE /tmp		;## Prefix TMP directory (will change)
    variable TMP 			;## Temporary directory (will change)
}

## Initialize temporary directory per user and pid
proc file::startup_tmp {} {
    global DIR_BASE

    variable TMP_BASE
    variable TMP
    
    append TMP_BASE /[ file tail $DIR_BASE ]

    set TMP $TMP_BASE/[ pid ]
    file mkdir $TMP
    file attributes $TMP_BASE -permissions 0711
    file attributes $TMP -permissions 0777
}

## remove temporary directory created by startup_tmp
proc file::cleanup_tmp {} {
    variable TMP_BASE
    variable TMP

    file delete -force $TMP

    # every now and then check all other tmp dirs and cleanup
    if { [ pid ] % 20 == 0 } {
	foreach dir [ glob -nocomplain $TMP_BASE/* ] {
	    if { 
		[ glob -nocomplain $dir/* ] == {} 	&&
		[ clock seconds ] - [ file mtime $dir ] > 60*60 
	    } {
		file delete -force $dir
	    }
	}
    }

}

## Returns inode of filename
proc file::inode {file} {

    file stat $file stat
    return $stat(ino)	   
} 

## Returns file from list with given inode
proc file::with_inode {files inode} {
    set inodes {}
    foreach file $files {
	file stat $file stat
	if { $inode == $stat(ino) } {
	    return $file
	}
	lappend inodes $stat(ino)
    }
    error "No file in list with given inode\n\t$inodes\n\t$inode"
} 



## Returns the conanical pathname of file: absolute and direct (without ..)
proc file::canonical_pathname {fx} {

    if { ! [ regexp {^/} $fx ] } { set fx [ pwd ]/$fx }
    while { [ regsub {/[^/\.\.]+/\.\.} $fx {} fx ] } {}
    return $fx
}

## Returns a text for a directory
proc file::valid_dir_name {text} {
    
    regsub -all { } $text _ text
    regsub -all {/} $text : text
    regsub -all {[^a-zA-Z0-9_:]} $text {} text
    return $text
}


## Returns the content of a file
proc file::read_in {fx {translation auto}} {
    
    set fd [ open $fx r ]
    fconfigure $fd -translation $translation
    set text [ read  $fd ]
    catch { close $fd }
    return $text
}

## Writes content a file
proc file::write_out {fx data} {

    set fd [ open $fx "w" ]
    puts $fd $data
    catch { close $fd }
}

## Execute recursivelly chmod in given dir setting appropriate permissions.
## Extra safe: avoid world readable/writable
proc file::safe_permissions {dir} {

    exec find $dir -exec chmod go-rw \{\} \;
    exec find $dir -type d -exec chmod go+x \{\} \;
}


## Moves a directory/file from orig to dest (a directory)
proc file::move {orig dest {preserve 0}} {


    if { ! [ file isdirectory $dest ]  } {
	set dest [ file dirname $dest ]
    }

    file mkdir $dest
    file attributes $dest -permissions 0755

    set path $dest/[ file tail $orig ]
    if { [ file exists $path ] } {
	file delete -force -- $path
    }

    if  $preserve  { set type copy } else { set type rename }
    file $type -force -- $orig $dest
}

## Expand given variables and values bind to then in a command line
proc file::expand {line pairs} {

    foreach {var val} $pairs {
	namespace eval expand [ list set $var $val ]
    }
    
    return [ namespace eval expand [ list subst $line ] ]
}

## Set permissions $type for files fiven as remaining arguments
proc file::permissions {type args} {

    foreach fx $args {
	if [ file exists $fx ] {
	    file attributes $fx -permissions $type
	}
    }
}


## Dereferences a symbolic link chain
proc file::deref_link {file} {

    set type [ file type $file ]
    while { [ string compare $type link ] == 0 } {
	if [ regexp {^/} [ set ref [ file readlink $file ] ] ] {
	    # absolut link
	    set file $ref
	} else {
	    # relative link
	    set file [ file dirname $file ]/$ref
	}
	set type [ file type $file ]
    }
    return $file
}


## Recodes characters acording to the current platform (really needed?)
proc file::recode {data} {
    global tcl_platform
    
    switch $tcl_platform(platform) {
	unix {
	    regsub -all \r $data {} data
	}
    }
    return $data
}

## File f newer than g (sorting files by modification time)
proc file::newer {f g} {

    return [ expr [ file mtime $f ] > [ file mtime $g ] ]
}


## File type based on unix command file(1)
proc file::type {file} {
    variable FILE
    
    return [ exec $FILE $file ]
}


## Create a lockfile. Keep multiple lockfiles using $ref (resource name)
## Locks are automatically removed if locking process is not alive
proc file::lock {{ref ""}} {

    set lockfile [ lockfile $ref ]
    while { [ catch { set fd [ open $lockfile {RDWR CREAT EXCL} ] } ] } { 

	if [ catch { 
	    set fd [ open $lockfile r ] 
	    gets $fd pid
	    close $fd 
	} ] {
	    # cannot read lockfile, probably was released
	} else {
	    # check if process holding lock is alive
	    if [ file readable /proc/$pid ]  {
		# process holding lock is still alive ...
	    } else {
		# remove lock before retrying
		unlock $ref
	    }
	}
	# use waiting time to cleanup
	lock_cleanup
	# wait a random time to avoid race conditions
	after [ expr int(rand()*1000) ]	    
    }
    puts $fd [ pid ]
    catch { close $fd }
}

## Remove lockfile created with file::lock
proc file::unlock {{ref ""}} {
    set lockfile [ lockfile $ref ]
    
    catch { file delete -force -- $lockfile }
}

## Check all lockfiles and remove those whose process terminated
proc file::lock_cleanup {} {
    variable TMP_BASE

    foreach lockfile [ glob -nocomplain $TMP_BASE/Lock_mooshak_* ] {
	if [ catch { 
	    set fd [ open $lockfile r ] 
	    gets $fd pid
	    close $fd 
	} ] { 
	    # cannot read lockfile, probably was released
	} else {
	    # check if process holding lock is alive
	    if { ! [ file readable /proc/$pid ] } {
		catch { file delete -force -- $lockfile }
	    }
	}	    
    }
}

## Returns filename for lockfile
proc file::lockfile {ref} {
    variable TMP_BASE

    regsub -all / $ref _ ref
    return $TMP_BASE/Lock_mooshak_$ref
}

## Command line prefix for archiving given file
proc file::archive_command {file} {

    set type [ file extension $file ]    

    switch -regexp -- $type {
	.tar  	{ set command "tar cvf"  	}
	.tgz  	{ set command "tar cvzf" 	}
	.tbz2  	{ set command "tar cjf" 	}
	.zip	{ set command "zip" 	 	}
	default {
	    layout::alert "Archive in unknown format"
	    return
	}

    }

     return $command
 }


## Command line prefix for unarchiving given file
proc file::unarchive_command {file {stdout 0}} {
    
    set type [ file extension $file ]    

    if { $type == "" } {
	error "Unknown archive type"
    }

    if $stdout {
	switch -regexp -- $type {
	    .tar - .tgz	- .tbz2 - .gz	{ set extra "O"		}
	    .zip			{ set extra "-p"	}    	       
	    default 	{
		error "Archive in unknown format"
	    }
	}
    } else {
	set extra ""
    }
	
    switch -regexp -- $type {
	.tar	{ set command "tar x${extra}f"		}
	.tgz	{ set command "tar x${extra}zf"		}
	.gz	{ set command "tar x${extra}zf"		}
	.tbz2	{ set command "tar x${extra}jf"		}
	.zip	{ set command "unzip $extra -o"		}    	       
	default 	{
	    error "Archive in unknown format"
	}
    }

    return $command
}

## return the encoding type of given file
proc file::encoding {fx} {
    set line [ exec file $fx ]
    set line [ split $line : ]
    
    return [ string trim [ lindex [ lindex $line 1 ] 0 ] ]
}

## convert encoding
proc file::convert_encoding {fx from to} {
    
    catch { exec recode ${from}..${to} $fx } 
}

