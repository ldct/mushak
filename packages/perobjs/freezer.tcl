#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: freezer.tcl
# 
## (De)freeze directories. During replications (using rsync) it is not 
## possible to remove files and directories because other server would 
## replicate them back to the server. Instead one can freeze then, i.e.
## convert then into a compress archive (tgz) with the same name.
##
## By default, freeze and unfreeze update content window.
##
## TODO: Check frozen files with propagation
## TODO: Optimize procedure "frozen" using output of unix command "file"

package provide freezer 1.0

namespace eval freezer {

    variable TAR	tar	;# tar command

    global env
    lappend env(PATH) /bin

    namespace export freeze	;# freezes a directory
    namespace export frozen	;# checks if is frozen directory
    namespace export type	;# type of frozen directory
    namespace export content	;# content of frozen directory
    namespace export unfreeze	;# unfreezes a directory

}

package require data

## Freezes a directory
proc freezer::freeze {dir {update 1}} {
    variable ::file::TMP
    variable TAR
    
    set tmp $TMP/freeze
    
    exec $TAR czf $tmp $dir 
    file delete -force $dir 
    file rename $tmp $dir    

    if $update {
	content::show $dir  1
    }
}

## Checks if is frozen directory
proc freezer::frozen {dir} {
    variable TAR

    if [ file exists $dir ] {
	return [ expr ! [ catch { exec $TAR tzf $dir $dir } ] ]
    } else {
	return 0
    }
}

## Type of frozen directory
proc freezer::type {dir} {
    variable TAR
    variable ::data::Class_file

    set output "return ?"
    catch { set output [ exec $TAR xOzf $dir $dir/$Class_file ] } 

    return [ eval $output ]
}


## Content of frozen directory
proc freezer::content {dir} {
    variable TAR
    variable ::data::Data_file

    set output "?"
    catch { set output [ exec $TAR xOzf $dir $dir/$Data_file ] }
    regsub -all {(^|\n)set} $output "\n" output
    return  $output
}


## Unfreezes a directory
proc freezer::unfreeze {dir {update 1}} {
    variable ::file::TMP
    variable TAR

    set tmp $TMP/freeze

    file rename $dir $tmp        
    catch { exec $TAR xzf $tmp } 

    if $update {
	content::show $dir  1
    }
}

