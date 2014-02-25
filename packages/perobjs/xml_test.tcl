#!/bin/sh
# the next line restarts using tclsh \
PATH=$PATH:/usr/local/bin:/usr/contrib/bin  ; exec tclsh "$0" "$@"

#-*-Mode: TCL; iso-accents-mode: t;-*-	

proc test {} {
    set dir data/contests/bug/quiz

    set home [ format "%s/../.." [ file dirname [ info script ] ] ]
    
    cd $home
    
    source .config
    
    lappend auto_path packages
    
    file::startup_tmp
    
    set data [ exec cat "$dir/Content.xml" ]
    
    xml::unserialize $dir $data
}

# test



