#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Language.tcl
# 
## Programming language available for submission and related operations:
## compilation and execute in a safe environment
##
## TODO: teste without safeexec (or get ride of this option)

package provide Language 1.0

namespace eval Language {
    
    variable SafeExec [pwd]/bin/safeexec;#  safe execute shell
    variable Shell	/bin/sh		;# good old unix shell
    global env; set env(HOME) ""	;# workaround GCC bug

    variable ErrorMessage ;# last messages's error
    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Name		"Language name (ex: Java)"
	Extension	"Extension used for program files, without the dot (ex: java)"
	Compiler	"Name of compiler (ex: jdk)"
	Version		"Version of compiler (ex: gcj-java-3.2.2)"
	Compile		"Command line for compilation (ex: javac $file)"
	Execute		"Command line for execution (ex: java -classpath . $name)"
	Data		"Maximum size of data segment in bytes [Overrides MaxData defined in Languages]"
	Fork		"Maximum forks in execution [Overrides MaxExecFork defined in Languages] "
	Omit		"Regular expression matching lines to be ommited from the compilers output"

	UID		"Fixed User ID to compile and execute (Mono),\n overrides the MINUID-MAXUID range"
    }    

    array set Help {
	
	Compile		"Command line for compilation, including the following
 			variables:

   			$home	- Mooshak's home directory
                   	$file   - submission file name (with extension)
                   	$name   - submission file name (without extension)
                   	$extension  - extension
			$environment - Problem environment file
			$solution - Problem solution
			"
	Execute		"Command line for execution, including the following
 			variables:

   			$home	- Mooshak's home directory
                   	$file   - submission file name (with extension)
                   	$name   - submission file name (without extension)
                   	$extension  - extension
		   	$args    - arguments defined for each test
		   	$context - context file for each test

			"


    }


}
#-----------------------------------------------------------------------------
#     Class definition

Attributes Language {

    Fatal	fatal	{}
    Warning	warning {}        

    Name	text	{}
    Extension	text	{}
    Compiler 	text	{}
    Version	text	{}
    Compile	text	{}
    Execute	text	{}	
    Data	text	{}
    Fork	text	{}
    Omit	text	{}
    UID		text	{}
}

Operation Language::_update_ {} {

    check::reset Fatal Warning

    foreach var {Name Extension Compile Execute} {
	check::attribute Fatal $var
    }
    check::attribute Fatal Fork {^[0-9]*$}
    check::attribute Fatal Data {^[0-9]*$}
    foreach var {Compiler Version} {
	check::attribute Warning $var
    }

    set compiler [ file::expand 		\
		       [ lindex $Compile 0 ] 	\
		       [ list home [ pwd ] ]	]
    if { ! [ file executable $compiler ]  } {
	check::record Fatal value "Compiler is not executable" Compile $compiler
    }

    if { [ info exists UID ] && [ regexp {\d+} $UID] } {
	if { [ catch {
	    set mooshak_uid [ exec id -u ]
	} ] } {
	    check::record Warning var "Could not execute command" id 
	} else {
	    if { $mooshak_uid == $UID } {
		check::record Fatal value "Invalid UID (Mooshak's UID)" UID $UID
	    }
	}
    }

    return [ check::requires_propagation $Fatal ]
}

## Checks recursively all sub directories
Operation Language::check {} {
    
    check::dir_start
    check::vars Extension Compile Execute

    if { ! [ file executable [ lindex $Compile 0 ] ] } {
	check::report_error Fatal "Compiler is not executable"
    }
    check::dir_end
}

## Generates a string of flags for the compilation of execution command lines
Operation Language::limits {dir param_ {compile 0}} {
    # Params are defined in languages but changed by Submission
    upvar 3 $param_ Param

    set flags {}
    lappend flags --core  [ expr $Param(MaxCore) / 1024 ]
    if { [ info exists Data ] && [ regexp {^[0-9]+$} $Data ] } {
	lappend flags --mem   [ expr $Data / 1024 ]	
    } else {
	lappend flags --mem   [ expr $Param(MaxData) / 1024 ]
    }
    lappend flags --stack [ expr $Param(MaxStack) / 1024 ]

    if $compile {
	lappend flags --cpu  $Param(CompTimeout)
    } else {
	lappend flags --cpu  $Param(ExecTimeout)
    }

    lappend flags --clock $Param(RealTimeout)

    if { [ info exists UID ] && [ regexp {\d+} $UID] } {
	set uid [ userid $dir $UID $UID ]
    } else {
	set uid [ userid $dir  $Param(MinUID) $Param(MaxUID) ]
    }

    lappend flags --uids $uid $uid
    
    if { [ info exists Fork ] && [ regexp {^[0-9]+$} $Fork ] } {
	lappend flags --nproc $Fork
    } else {
	if $compile {
	    lappend flags --nproc $Param(MaxCompFork)
	} else {
	    lappend flags --nproc $Param(MaxExecFork)
	}
    }
    
    return $flags
}


## Compiles a source program file with this language
Operation Language::compile {dir file problem param_} {
    variable SafeExec
    variable Shell
    upvar 3 $param_ Param

    # compile only if a compilation line is given 
    if { [ string trim $Compile ] == "" } return

    set contest  [ contest::active_path ]
    set prob [ ::data::open $contest/problems/$problem ]
    foreach var { Environment Solution } {
	set auto_var [ string tolower $var ]
	if [ info exists ${prob}::${var} ] {
	    set $auto_var $contest/problems/$problem/[ set ${prob}::${var} ]
	} else {
	    set $auto_var ""
	}
    }


    # relax security temporarily 
    file::permissions go+rwx $dir
    file::permissions go+r $dir/$file $environment
    set other [ other_files_with_same_owner $dir $file ]
    if { $other != {} } {
	eval file::permissions go+rw $other
    }


    # compilation command line
    set vars [ list                                                     \
		   home		[ pwd ]					\
		   environment	$environment				\
		   solution	$solution				\
                   file         $file                                   \
                   name         [ file tail [file rootname $file] ]     \
                   extension    [ file extension  $file ]               ]
    set command_line  [ format {%s %s --silent --exec %s -c \
				    "umask 0007 ; cd %s ; %s"} \
			    $SafeExec \
			    [ ${_Self_} limits $dir Param 1 ]	\
			    $Shell				\
			    $dir				\
			    [ file::expand $Compile $vars ]	]

    # execution compilation command
    set here [ pwd ]
    if { ! [ catch {

	set out [ eval exec $command_line ]

    } msg ] } { 
	# some compilers (notably fpc) write errors in stdout !!
 	set msg $out$msg
	cd $here
    } else {
	cd $here
    }

    # tighten security
    file::permissions go-rwx $dir
    file::permissions go-r $dir/$file $environment
    if { $other != {} } {
	eval file::permissions go-rw $other
    }

    # remove "valid" parts of error (again, fpc banners)
    regsub -all $Omit $msg {} msg

    if { $msg != "" } { 
	if { [ contest::requires_reevaluation $msg ] } {	    
	    error $msg		$msg 	7
	} else {
	    error $msg		$msg	11 
	}
    }
}

## Executes an object program for this language with the given input file;
## returns the output
Operation Language::execute {dir file args context input param_} {
    variable SafeExec
    upvar 3 $param_ Param
    global errorInfo
    global errorCode
    variable ErrorMessage
    
    set errorInfo ""
    set errorCode 0

    # excute only if an execution line is given 
    if { [ string trim $Execute ] == "" } return

    # relax security
    file::permissions go+r $dir/$file $input $context
    file::permissions go+rwx $dir
    set other [ other_files_with_same_owner $dir $file ]
    if { $other != {} } {
	eval file::permissions go+rw $other
    }

    # create command line
    set vars [ list							\
		   home		[ pwd ]					\
		   file         $file                                   \
		   name         [ file tail [file rootname $file] ]     \
		   extension    [ file extension  $file ]               \
		   args         $args                                   \
		   context      $context        ]    
    set command_line [ format {%s %s --usage "%s" --exec %s }		\
			   $SafeExec                            	\
			   [ ${_Self_} limits $dir Param ]      	\
			   [ contest::usage_file ]              	\
			   [ file::expand $Execute $vars ] ]
    if [ file readable $input ] {
	append command_line [ format {< %s} $input ]
    }

    # execute 
    set here [ pwd ] 
    cd $dir

    if [ catch {

	set fd [ open "| $command_line " r ]
    } msg ] {
	cd $here
	error $msg $errorInfo $errorCode
    } else {
	cd $here
    }

    # process output
    set output ""
    set output [ read $fd [ expr $Param(MaxOutput) + 1 ] ]
    catch { close $fd } ErrorMessage

    # tighten security
    file::permissions go-rwx $dir
    file::permissions go-r $dir/$file $input $context
    if { $other != {} } {
	eval file::permissions go+rw $other
    }

    return $output
}

## Return a user id (UID) in the range [ $min , $max ]
## If a file with an UID in that range exists in $dir then it is returned
## Otherwise a "random" UID is generated in that interval
proc Language::userid {dir min max} {

    set uid 0

    foreach fx [ glob -type f -nocomplain $dir/* ] {

	set fxuid [ contest::uid_file_owner $fx ]

	if { 
	    [ regexp {^\d+$} $fxuid ] && 
	    $fxuid >= $min && 
	    $fxuid <= $max 
	} {
	    set uid $fxuid
	    break
	}
    }
    if { $uid == 0 } {
	set uid  [ expr $min + [ clock clicks ] % ($max - $min +1) ]
    }

    return $uid
}

## returns other files in given directory with the same owner of given file
proc Language::other_files_with_same_owner {dir file} {

    set other [ glob -nocomplain $dir/* ]
    set pos_file  [ lsearch $other $dir/$file ]
    set other [ lreplace $other $pos_file $pos_file ]
    set owner [ file attributes $dir/$file -owner ]
    foreach one $other {
	if { ! [ string equal [ file attributes $one -owner ] $owner ] } {
	    set pos_one  [ lsearch $other $one ]
	    set other [ lreplace $other $pos_one $pos_one ]
	}
    }

    return $other
}