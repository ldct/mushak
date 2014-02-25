#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: utils.tcl
# 
## Cache managemente

package provide cache 1.0

package require file


namespace eval cache {

    variable RECENT_CHANGE	180 ;# seconds after change from team
    variable FRESH_LISTING	 60 ;# seconds while listing is fresh

    variable CACHE_DIR_NAME .cache

    variable Filename
    variable Channel

}

## Restores TCL file saved in $pathname to calling context
## Returns true if restoring was successful 
proc cache::restore {pathname}  {

    if { [ catch { uplevel source $pathname } ] } {
	return 0
    } else {
	return 1
    }
}


## Reopens $pathname for update and returns file descriptor
## Reopen file is not immediately rewritten
## A file descriptor to a temporary file in this process is returned
## When file is written then cache::replace must be invoked  
## A lock on $pathname is used to avoid concurrency problems
proc cache::reopen {pathname}  {
    variable ::file::TMP
    variable Filename

    set name [ file tail $pathname ]
    set dir [ file tail [ file dirname $pathname ] ]

    set cache_file $pathname

    set temp_cache_file ${TMP}/${dir}_${name}

    file::lock $cache_file
    set fd [ open $temp_cache_file "w" ]
    
    set Filename(cache,$fd)	$cache_file
    set Filename(temp,$fd)	$temp_cache_file

    return $fd
}

## Replaces the file associated with this descriptor 
## with the content on this temporary file
## Releases lock on $pathname 
proc cache::replace {fd} {
    variable Filename

    set cache_file	$Filename(cache,$fd) 
    set temp_cache_file	$Filename(temp,$fd) 

    catch { close $fd }
    
    file rename -force $temp_cache_file $cache_file
    file::unlock $cache_file
}


## Creates a patch (a $line) on the cache file
## given by $pathname
proc cache::patch {pathname line} {

    set name [ file tail $pathname ]
    set dir [ file tail [ file dirname $pathname ] ]

    set cache_file $pathname

    file::lock $cache_file
    set fd [ open $cache_file "a" ]
    puts $fd $line
    catch { close $fd }
    file::unlock $cache_file
}



proc cache::hash {} {
    variable ::cgi::Field

    set hash {}
    foreach name [ lsort [ array names Field ] ] {
	lappend hash $name:$Field($name)
    }
    # avoid having an empty file cache name
    if { $hash == "" }  {
	# this is the default listing: no parameters
	set hash default
    }

    return [ join $hash + ]
}


proc cache::start {path} {
    variable RECENT_CHANGE
    variable FRESH_LISTING
    variable CACHE_DIR_NAME 
    variable Container
    variable ::Session::Conf

    set cache_dir $path/$CACHE_DIR_NAME
    file mkdir $cache_dir
    set Container $cache_dir/[ cache::hash ]
    set content {} 

    set now [ clock seconds ]

    if { 
	( ! [ file exists $Container ] )			||
	($now - $Conf(modified)) < $RECENT_CHANGE		||
	($now - [ file mtime $Container ]) > $FRESH_LISTING	||
	[ catch { set content [ file::read_in $Container ] } ]
    } {

	chan push stdout ::cache::tee

    } 
    return $content 
    
}

proc cache::stop {} {
    chan pop stdout
}

## Channel transformation to store stdout on cacheable file
proc cache::tee { command {handle {}} {data {}}} {
    variable Container
    variable Channel

    set available_commands { finalize initialize flush write }

    switch $command {
	
	initialize 	{ 
	    switch $data {
		write {
		    set Channel($handle) [ open $Container "w" ]
		    return $available_commands		
		}
		default {
		    set message "Channel transformation initialization: "
		    append message "unimplement mode: $data" 
		    error $message
		}
	    }
	}
	write 		{ 
	    puts -nonewline $Channel($handle) $data 
	    return $data	
	}
	flush 		{ flush	$Channel($handle)			}
	finalize 	{ close $Channel($handle)			}
	default 	{ 
	    set message "Channel transformation: "
	    error "unimplemenrd subcommand: $command"		
	}
    }
} 

