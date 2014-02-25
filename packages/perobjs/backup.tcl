#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: backup.tcl
# 
## Backup and recovery of data in directories. Backup files have the same as
## data files but with a suffix (a human readable timestamp). 
## When a backup file is used for data recovery the current data is stored 
## in a redo file. Redo and backup files are similar but use a different suffix
## separator. Most procedures in this file use a flag to specify if a redo file
## (instead of a backup file) must be used; the default is false.
##


package require data

namespace eval backup {
    variable Backup_sep		.	;## separator for backup files sufix
    variable Redo_sep		:	;## separator for redo files sufix
    variable Max_backups	5	;## maximum backups per directory

    namespace export save
    namespace export recover
    namespace export can_recover
}

## Save a backup of current data (before saving changes)
proc backup::record {dir} {
    variable Max_backups
    variable ::data::Data_file

    file copy -force -- $dir/$Data_file [ filename $dir ]
    # garbage collection (these modifications cannot be undone)

    foreach fx [ lrange [ enum $dir ] $Max_backups end ] {
	file delete -force $fx
    }

}

## Recovers last backup/redo file
proc backup::recover {dir {redo 0}} {
    variable ::data::Data_file
        
    file copy   -force --  $dir/$Data_file [ filename $dir [expr ! $redo] ]
    file rename -force -- [ lindex [ enum $dir $redo ] 0 ] $dir/$Data_file

}


## Can recover from a backup/redo file?
proc backup::can_recover {dir {redo 0}} {
    return [ expr [ llength [ enum $dir $redo ] ] > 0 ] 
}


## Enumerates backup/redo files in given directory 
proc backup::enum {dir {redo 0}} {
    variable ::data::Data_file
    variable Backup_sep
    variable Redo_sep

    if $redo {
	#-increasing
	set sep $Redo_sep	;	set order -decreasing
    } else {
	set sep $Backup_sep 	;	set order -decreasing
    }
    return [ lsort $order [ glob -nocomplain $dir/${Data_file}${sep}* ] ]
}

## Generates a filename for backup/redo files
proc backup::filename {dir {redo 0}} {
    variable ::data::Data_file
    variable Backup_sep
    variable Redo_sep

    if $redo { set sep $Redo_sep } else { set sep $Backup_sep    }
    set now [ clock format [ clock seconds ] -format {%Y%m%d%H%M%S} ]
    return $dir/${Data_file}${sep}${now}
}
