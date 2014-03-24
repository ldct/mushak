#
# Mooshak: managing  programming contests on the web            April 2001
# 
#                       Zé Paulo Leal           
#                       zp@dcc.fc.up.pt
#
#-----------------------------------------------------------------------------
# file: execute.tcl
# 
## Command line processing: 
## Responsible for authorization, inicialization, and MIME type classification 
## Authorization is based on the following profiles:
##      <ul>
##              <li>admin</li>
##              <li>judge</li>
##              <li>runner</li>
##              <li>team</li>
##              <li>guest</li>  
##      </ul>
##
## TODO: make cript a loadable library
## TODO: replace ALL (not only in this file) calls to report_error by error

package provide execute 1.0

package require Session

namespace eval execute {

    variable PROFILE_LOG profile_log
    
    variable Unsafe             ;## Usafe commands whose args are not protected
    variable Init               ;## Commands requiring initialization (cookies)
    variable Mime               ;## MIME types for request (except text/HTML)
    variable ResponseMime {}    ;## MIME used in this response
    variable Headed     0       ;## Was header already outputed?
    variable Audit_log audit_log;## Audit log filename
    variable PackageOf          ;## Array with package of command
    variable ServicePackageOf   ;## Array with package of command for REST
    variable DebuggingMachines  ;## Name of machine used for debugging

    set DebuggingMachines { khato }

    # switch off help due to problems with excess of cookies

    array set PackageOf {
        admin           admin
        analyze         team
        answer          team
        ask             team
        asked           team
        banner          common
        check           common
        clone           Session
        code            team
        config          Session
        content         content
        copy            clipboard
        cut             clipboard
        data            navigate
        description     common
        edit            content
        empty           common
        export          content
        exporting       content
        faq             team
        feedback        team
        file            admin
        flag            guest
        form            team
        freeze          freezer
        guest           common
        grade           team
        htools          team
        help            help
        image           common
        import          content
        importing       content
        inspect         content
        judge           common
        listing         listing
        login           Session
        link            clipboard
        logout          Session
        message         admin
        operation       admin
        paste           clipboard
        print           team
        register        guest
        remove          navigate
        reset           content
        report          common
        runner          common
        sms             common
        target          clipboard
        team            team
        top             common
        undo            admin
        unfreeze        freezer
        view            team
        vtools          common
        redo            admin
        relogin         Session
        split           common
        warn            common
        warned          common
    }


    ## MIME Types of non-HTML responses
    ## Requests with a void MIME type ({}) will set their types
    array set Mime {
        team            {}
        grade           {}
        code            text/plain
        flag            image/png
        image           {}
        report          {}
        check           {}
        content         {}
        inspect         {}
        serialize       text/plain
        login           {}
        file            {}
    }
    
    ## These commands are unsafe: their arguments are not protected
    set Unsafe {
        data
        edit
        file
        content
        import
        importing
        export
        exporting
        inspect 
        message
        operation
        freeze
        unfreeze
        copy
        cut
        paste
        link
        target
        undo
        redo
        reset
    }

    namespace export process    ;## Executes command line passed as an argument
}



## Executes command line in argv or CGI request
## In argv command is the first argument
## In CGI request command is cgi::field with named command
proc execute::command_line {} {
    variable PackageOf

    file::startup_tmp

    if { [ catch {

        cgi::data                   
        cgi::read_cookies

        parse_command_line command arguments        

        protect_fields $command

        if [ has_session_hash ] {

            Session::init                               \
                [ cgi::cookie mooshak:session "" ]      \
                [ cgi::cookie mooshak:authorization "" ]\
                [ cgi::field  contest         "" ]      \
                [ set user [ cgi::field  user "" ] ]    \
                [ cgi::field  password        "" ]      \
                $command
                    
            translate::load

            # execute command as a CGI (generate last header line with MIME)
            if { [ info exists PackageOf($command) ] } {
                package require $PackageOf($command)

                state::process_cookies $PackageOf($command) $command

                if [ Session::authorized $user ] {
                    protect_arguments $command arguments

                    header $command

                    if [ catch {
                        eval ::$PackageOf($command)::$command $arguments
                        
                        puts "XUANJI"
                        puts $PackageOf($command)
                        puts $command
                        puts $arguments

                    } msg ] {
                        # this exception MUST be caught at this point
                        global errorInfo errorCode
                        error $msg $errorInfo $errorCode
                    }
                } else {
                    
                    header 
                    Session::authenticate $command $arguments       
                }  
            } else {
                # error messages are injected in HTML, a door for XSS attacks
                set safe_command [ layout::protect_html $command ]
    
                error  "invalid command <code>$safe_command</code> "
            }
            audit_log $arguments
            Session::close
        } else {
            give_session_hash $command
            header
        }
    } msg ] } { 
        header
        report_error $msg
    }

    file::cleanup_tmp   
}


## Checks if current session URL has an hash
proc execute::has_session_hash {} {
    global env 
    
    set re [ format {%s/(\d+)((\?|\+|/).*)?$} [ file tail [ info script ] ] ]
    if [ regexp $re $env(REQUEST_URI) - session ] {
        return 1
    } else {
        # no session found
        return 0
    }
}

## Give a session hash to the URL of current session
proc execute::give_session_hash {command} {
    global env      

    set re [ format {%s/(\d+)((\?|\+|/).*)?$} [ file tail [ info script ] ] ]

    if { 
        ! [ string equal $command clone ]       &&
        [ info exists env(HTTP_REFERER) ]       &&
        [ regexp $re $env(HTTP_REFERER) - hash ]
    } {
        # previous request had a session (using it for backward compability)
        # this copes with links in reports generated in previous versions
        # (and with links in the admim interface that were not updated :-)
        # provided that this is not the clone command being processed...
    } else {
        # generating a new random hash 
        regsub {\.} [ expr rand() ] {} hash
        set hash [ string trimleft $hash 0 ]
    }

    set script [ file tail [ info script ] ]
    regsub  $script $env(REQUEST_URI) $script/$hash uri

    puts "Status: 302 Redirect"
    puts "Location: $uri"

}



## Reads command line broken in command name and list of arguments
proc execute::parse_command_line {command_ arguments_} {
    global argv
    upvar $command_  command
    upvar $arguments_ arguments

    # remove query strings from command line (argv)
    # some apache servers do this automatically, others dont !!
    if { [ regexp {^{(\w+=\w*(\\&)?)+}$} $argv ] } { set argv "" }

    # empty command line sometimes contain an empty list !
    # this happens in Ubuntu 9.10 (but not in previous versions)
    if { $argv == {{}} }  { set argv {} }

    # split command line in command and arguments    
    if { $argv != "" } {
        set command             [ lindex $argv 0 ]
        set arguments   [ lrange $argv 1 end ]
    } elseif { [ set command [ cgi::field command "" ] ] != "" } {
        set arguments $argv
        
    } elseif { [ set arguments [ download_file ] ] != "" } {
        set command file
    } else {
        set command top
        set arguments ""
    }
}

## Execute a procedure that returns a response of a given MIME type.
## The procedure's output is  buffered before sending the mime type.
## If an error is catched during the execution of the procedure then
## it is reported in a standard (text/HTML) response.
proc execute::generator {command_line {mime text/xml}} {
    global ENCODING

    if { [ catch {      
        set output [ uplevel $command_line  ]
    } msg ] } {
        header 
        report_error $msg
    } else {
        append mime [ format "; charset=%s" $ENCODING ]
        puts [ format "Content-type: %s\n" $mime ]
        puts $output
    }
}

## Returns sub-directory of this executeable
## Dirty hack to force download a file with the correct filename
proc execute::download_file {} {
    global env

    if { [ info exists env(SCRIPT_NAME) ] &&
         [ info exists env(REQUEST_URI) ] &&
         [ regexp [ format {^%s/\d+/(.*)$} $env(SCRIPT_NAME) ] \
               $env(REQUEST_URI) - file ]
     } {
        return $file
    } else {
        return {}
    }          
}


# Record audit log: date: profile user command arguments     
proc execute::audit_log {arguments} {
    variable ::Session::Conf
    variable Audit_log

    flush stdout

    if { ! [ info exists Conf(user) ] } {
        set Conf(user) {}
    }
    set session [ file tail $Conf(session) ]

    file::lock $Audit_log
    set fd [ open $Audit_log a ]
    puts $fd [ format {%-20s %-20s %-8s %-8s %-10s %s } \
                   [clock format  [clock seconds] -format {%Y/%m/%d %H:%M:%S}]\
                   $session $Conf(profile) $Conf(user) \
                   $Conf(command) $arguments ]

    flush $fd  ;  close $fd
    file::unlock $Audit_log
}



## Generates CGI headers (not using MIME feature from cgi package)
proc execute::header {{command ""}} {
    variable Mime 
    variable Headed
    variable ResponseMime
    global ENCODING

    if $Headed { return }

    if [ info exists Mime($command) ] {
        set ResponseMime $Mime($command)
    } else {
        set ResponseMime text/HTML
    }

    puts "Pragma: no-cache"
    puts "Expires: -1"
    if { $ResponseMime == {} } {
        # command will take care of its own MIME type
    } else {
        append ResponseMime [ format "; charset=%s" $ENCODING ]
        puts [ format "Content-type: %s\n" $ResponseMime ]
        set Headed 1
    }
}



## Special characters used in pathnames and TCL command execution
set execute::DANGEROUS_RE {\.\.|\/|\[|\]|\;}

## Protect declared CGI variables  from possible tampering
## Special characters used in pathnames and command execution are removed
proc execute::protect_fields {command} {
    variable ::cgi::Field
    variable Unsafe
    variable DANGEROUS_RE

    if { [ lsearch $Unsafe $command ] == -1 } {     
        foreach var [ array names Field ] {
            regsub -all $DANGEROUS_RE $Field($var) {} Field($var)
        }    
    }
}

## Protect  CGI variables argv from possible tampering
## Special characters used in pathnames and command execution are removed
## Commands with admin authentication may preserve dangerous arguments
proc execute::protect_arguments {command arguments} {
    variable ::Session::Conf
    variable ::cgi::Field
    variable Unsafe
    variable DANGEROUS_RE

    if { [ lsearch $Unsafe $command ] == -1 } {     

        foreach arg $arguments {
            upvar $arg v

            regsub -all $DANGEROUS_RE $v {} v
        }

    } else {
        if { ! [ string equal $Conf(profile) admin ] } {
            header
            report_error "Unsafe command, invalid profile" $Conf(profile)
        }
    }
}


##  
proc execute::profile {command {label ""}  } {
    variable PROFILE_LOG

    set time [ uplevel time [ list $command ] ]
    if { $label == "" } { set label [ lindex $command 0 ] }
    set time [ expr [ lindex $time 0 ] / 1000.0 ]
    set fd [ open $PROFILE_LOG a ]
    puts $fd [ format {%-3.3f %15s } $time $label ]
    close $fd
}

## Reports an error to the user
proc execute::report_error {message {value ""} {mime ""}} {
    global errorInfo
    global DIR_BASE
    variable ::Session::Conf
    variable DebuggingMachines
    variable ResponseMime

    if { ! [ info exists Conf(style) ] } { set Conf(style) conf }

    cd $DIR_BASE

    set message [ translate::sentence $message ]
    record_error [ format {%s: %s} $message $value ]

    if { $value != "" } {
        set message [ format {%s: <code>%s</code>} $message $value ]
    }

    
    if { [ lsearch $DebuggingMachines [ exec hostname ] ] > -1 } {
        set show_alert true
    } else {
        set show_alert false
    }

    regsub -all {<.*?>} $errorInfo {} clean_message
    regsub -all "\n" $clean_message {\n} clean_message
    regsub -all {\'} $clean_message {` } clean_message

    switch -regexp -- $ResponseMime {
        text/HTML - 
        text/html               { set template report_error.html        }
        text/xml                { set template report_error.xml         }
        text/plain - 
        default                 { set template report_error.txt         }
    }
    template::load $template
    template::write

    exit
}

## Records an unexpected occurrence (probably an error)
proc execute::record_error {message} {
    variable ::Session::Conf

    if { [ info exists Conf(user) ] && $Conf(user) != "" } {
        set user $Conf(user)
    } else {
        set user ?
    }

    # possible log files 
    set paths data/error_log
    if [ contest::active 0 ] {
        set     contest [ contest::active_path    ] 
        lappend paths   [ list $contest/error_log ]
    } 

    # select an output stream to a log file (default: stdout)
    set fd stdout
    foreach path $paths {
        if { 
            (   [file exists $path] && [file writable $path] ) ||
            ( ! [file exists $path] && [file writable [file dirname $path]] )
        } {
            set fd [ open $path a ]
            break
        } 
    }
    
    set date [ clock format [ clock seconds ] -format {%Y/%m/%d %H:%M:%S} ]
    puts $fd "$date $user: $message"  

    if { ! [ string equal stdout $fd ] } {
        catch { close $fd }        
    }

}

# returns list of commands 
proc execute::commands {} {
    variable PackageOf

    return [ array names PackageOf ] 
}

proc execute::debug args {
    variable ::Session::Conf
    variable ::cgi::Field
    global env    

    if { $Conf(authorization) != "" && $Conf(user) != "" } return

    puts stderr $args 
    foreach v {authorization user} {
        if { $Conf($v) == "" } { puts stderr "missing $v" }
    }
}

