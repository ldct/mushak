#!/bin/sh
# the next line restarts using tclsh \
PATH=$PATH:/usr/local/bin:/usr/contrib/bin  ; exec tclsh "$0" "$@"

if { [ catch {

    set fd [ open $env(OBTAINED) ]
    set output [ string trim [ read $fd ] ]
    catch { close $fd }

    if { [ regexp {^\d+$} $output ] } {
	
	if { $output <= 100 } {
	    exit 0
	} else {
	    puts "output greater then 100 ($output)"
	    exit 2
	}
	
    } else {
	puts "output not a positive integer ($output)"
	exit 2
    }
} msg ] } {
    puts $msg 
    exit 7
}