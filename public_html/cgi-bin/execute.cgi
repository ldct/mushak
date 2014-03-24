#!/bin/sh
# the next line restarts using tclsh \
PATH=$PATH:/usr/local/bin:/usr/contrib/bin  ; exec tclsh "$0" "$@"

#-*-Mode: TCL; iso-accents-mode: t;-*-	

set errorCode NONE

cd ../..

lappend auto_path packages

source .config

execute::command_line