
# Mooshak: managing  programming contests on the web		April 2011
# 
#			Zé Paulo Leal 		
#			zp@dcc.fc.up.pt
#
#-----------------------------------------------------------------------------
# file: execute.tcl
# 
## REST Web service processing: 
#


package provide service 1.0

package require template
package require content

namespace eval service {
    variable ErrorContext 	""
    variable BIND_CHAR		"."	;# char binding contest and language
    					;# in capabilities
    variable XMLLINT "/usr/bin/xmllint" ;# lint command for validating XML
    variable Audit_log	    service_log ;# service audint log
    variable Message_Id		0	;# message sequencial count
}

namespace eval Session {
    variable Conf 

    set Conf(style) base

}


#
# Evaluate a service request: prepare context, process request and handle errors
proc service::process {} {
    variable ErrorContext

    if { [ catch {
	file::startup_tmp

	cgi::data    		    
	# cgi::read_cookies ;# no need for cookies 

	parse_request function arguments

	if { [ set lang [ cgi::field lang "" ] ] != "" } {
	    variable ::Session::Conf

	    set Conf(language) $lang
	    translate::load
	}

	switch $function {

	    evaluate { process_evaluate $arguments	 }
	    report   { process_report   $arguments	 }
	    content  { process_content  $arguments	 }
	    default  { error "invalid request: $function" }
	}       

	audit_log $function $arguments
    } error_message ] } {	
	execute::header
	execute::report_error $error_message $ErrorContext
    }

    file::cleanup_tmp	
}

proc service::get_message_id {} {
    variable Audit_log
    variable Message_ID
    
    if [ catch {
	if [ file readable $Audit_log ] {
	    set Message_ID [ lindex [ exec  wc -l $Audit_log ] 0 ]
	} else {
	    set Message_ID 0
	}
    } ] {
	    set Message_ID 0
    }

    return $Message_ID
}


# Record audit log: date: profile user command arguments     
proc service::audit_log {request sub_request} {
    variable Audit_log
    variable Message_Id

    flush stdout

    set requester [ get_requester_id ]

    set arguments {}
    foreach name [ array names ::cgi::Field ] {
	lappend arguments $name=$::cgi::Field($name)
    }


    file::lock $Audit_log
    set fd [ open $Audit_log a ]
    puts $fd [ format {%-8s %-20s %-20s %-8s %-8s %s } 			      \
		   $Message_Id						      \
		   [clock format  [clock seconds] -format {%Y/%m/%d %H:%M:%S}]\
		   $requester $request $sub_request $arguments ]

    flush $fd  ;  close $fd
    file::unlock $Audit_log
}




## Parse request URI for service request and arguments
proc service::parse_request {function_ arguments_} {
    global env
    upvar $function_ function
    upvar $arguments_ arguments

    # puts stderr REQUEST_URI=$env(REQUEST_URI)

    regexp {cgi-bin/([^/?]+)/?([^\?]*).*$}  \
	$env(REQUEST_URI) - function arguments

    # remove pathname elements (.. and trailing /) from arguments
    # they are used to create pathnames
    regsub -all {^/|\.\.} $arguments {} arguments

}


## evaluate service request: listCapabilities & evaluateSubmission
proc service::process_evaluate {capability} {
    variable Token

    set template::NeedHTTPHeader 1

    set message_id 	[ get_message_id ]
    set message_date	[ xsd_dateTime ] 
    set request_date    [ xsd_dateTime ] 

    set problem_id	[ cgi::field id  	"" ]
    set program		[ cgi::field program	""] 


    if { $capability == "" } {
	set request	[ show_request ListCapabilities ]
	set reply	[ list_capabilities ]
    } else {
	set request	[ show_request EvaluateSubmission ]
	set report	[ evaluate_submission $capability $problem_id $program ]

	template::load erl.xml

	set token $Token
	set token_element     [template::formatting request_process_token ]
    set reply [ join [ list $token_element $report ] \n ]
    }

    set reply_date [ xsd_dateTime ]

    template::record message
    respond  [ template::restore ]    

}

## return a report given a token
proc service::process_report {token} {
    variable BIND_CHAR

    template::load erl.xml

    set token_pair	[ split $token $BIND_CHAR ]
    set contest_id	[ lindex $token_pair 0 ]
    set submission	[ lindex $token_pair 1 ]

    set message_id 	[ get_message_id ]
    set message_date	[ xsd_dateTime ] 
    set request_date    [ xsd_dateTime ] 

    set contest 	[ get_contest $contest_id "evaluation" ] 
    set team_id		[ get_authorized_team_id $contest ]


    if { [ string equal $submission "" ] } {
	error "Undefined submission"
    }

    set dir "$contest/submissions/$submission"
    if { ! [ file exists $dir ] } {
	error "Non existing submission: $submission"
    }

    set sb [ data::open $dir ]

    if { ! [ info exists ${sb}::Report ] } {
	error "Undefined report"
    }

    set request [ show_request GetReport ]

    set token_element [template::formatting request_process_token ]
    set report [ file::read_in $dir/[ set ${sb}::Report ] ]
    
    set reply [ join [ list $token_element $report ] \n ]

    set request_date [ xsd_dateTime ]
    set reply_date [ xsd_dateTime ]

    
    template::record message
    set message [ template::restore ]    

    respond $message
}

## return a problem given a token
proc service::process_content {token} {
    variable BIND_CHAR
    variable ::content::ArchiveType

    set token_pair	[ split $token "/" ]
    set contest_id	[ lindex $token_pair 0 ]
    set problem		[ lindex $token_pair 1 ]

    if { [ string equal $contest_id "" ] } {
	respond [ list_available_contests ]
	return 
    }

    set contest 	[ get_contest $contest_id "content" ] 
    set team_id		[ get_authorized_team_id $contest ]

    if { [ string equal $problem "" ] } {
	respond [ list_available_problems $contest_id ]
	return
    }

	
    set content_dir	"$contest/problems/$problem"
    set create_dtd 	0
    set create_archive  1
    
    set data_file [ content::create_data_file 	\
		    $content_dir $create_dtd $create_archive $ArchiveType ]
    
    content::send_file_content_as_HTTP_response "$content_dir/$data_file"
}

proc service::list_available_contests {} {
    global DIR_BASE
    global URL_BASE
    global env


    template::load rs.xml

    set server [ file tail $DIR_BASE ]
    set base [ format "%s/cgi-bin/content" $URL_BASE ]
    if [ info exists env(REQUEST_URI) ] {
	set source $env(REQUEST_URI)
    } else {
	set source $base
    }


    set request_message [ format "Available collections in %s" $server ]
    set n_collections 0

    foreach contest [ glob -type d -nocomplain data/contests/* ] {

	if [ catch {
	    set ct [ data::open $contest ]
	} ] continue

	if [ $contest is_service content ] {
	    incr n_collections
	    set collection [ format "/%s/" [ file tail $contest ] ]
	    set name [ set ${ct}::Designation ]

	    template::record collection
	}
    }

    if { $n_collections == 1 } { set plural  "" } else { set plural "s" }
    set response_message \
	[ format "%d collection%s found in %s" $n_collections $plural $server ]

    set resources [ template::restore ]    
    set response [ template::formatting response ]

    return [ template::formatting result ]
}

proc service::list_available_problems {contest} {
    global URL_BASE
    global env


    template::load rs.xml

    set base [ format "%s/cgi-bin/content" $URL_BASE ]
    if [ info exists env(REQUEST_URI) ] {
	set source $env(REQUEST_URI)
    } else {
	set source $base
    }

    set collection /$contest/
    set request_message "Available problems in $contest"
    set n_problems 0


    foreach problem [ glob -type d -nocomplain \
			  data/contests/$contest/problems/* ] {

	if [ catch {
	    set pb [ data::open $problem ]
	} ] continue

	incr n_problems
	set id    [ file tail $problem ]
	set title [ set ${pb}::Title ]
	set name [ set ${pb}::Name ]

	template::record resource	
    }

    set response_message \
	[ format "%d problems found in %s" $n_problems $contest ]

    set resources [ template::restore ]    
    set response [ template::formatting response ]

    return [ template::formatting result ]
}

proc service::set_context_variables {source_ base_} {
 
}
    




## Send response message on the stdout 
proc service::respond {message} {
    if [ cgi::field validate "0" ] { validate $message }
    
    puts "Content-type: text/xml\n"
    puts $message
}

## Validates ERL message using xmllint and raises exceptions if errors found
proc service::validate {message} {
    variable XMLLINT
    variable ErrorContext
    variable ::file::TMP
    global errorCode
    

    set pathname $TMP/erl_message.xml
    set fd [ open $pathname "w" ]
    puts $fd $message 
    close $fd

    if { [ catch {
	exec $XMLLINT --noout --schema public_html/styles/erl.xsd $pathname
    } msg ] } {
	if { ! [string equal $errorCode "NONE" ] } {
	    set  ErrorContext $msg
	    switch [ lindex $errorCode 2 ] {
		0 	{}
		1	{ error "Malformed ERL message"    		  }
		3 - 4	{ error "Invalid ERL message"    		  }
		5 	{ error "Error in ERL Schema definition"    	  }
		default	{ error "Unexpected validation error: $errorCode" }
	    }
	}
    }
}


## Process the evaluation of a submission
proc service::evaluate_submission {capability lo program} {
    variable BIND_CHAR
    variable ::Session::Conf
    variable Token undefined

    # sanity checks
    if { $program == "" } 	{ error "Missing program to evaluate" }
    if { $lo == "" } 		{ error "Missing problem or learning object" }

    set capability_pair [ split $capability  $BIND_CHAR ]

    set contest_id	[ lindex $capability_pair 0 ]
    set language	[ lindex $capability_pair 1 ]

    set contest 	[ get_contest $contest_id  "evaluation" ]

    set team_id		[ get_authorized_team_id $contest ]

    set problem_id	[ get_problem $contest $lo ]

    set Conf(contest)   $contest_id
    set Conf(user)	$team_id
    set Conf(capability) $capability

    cgi::field_value problem $problem_id

    data::open $contest/submissions

    set dir	[ service::transaction submissions $problem_id $team_id ]
    set sub	[ data::new $dir Submission ]

    set Token [ join [ list $contest_id [ file tail $dir ] ] $BIND_CHAR ]

    if { [ $dir receive ] } {

	set message {}
	data::record $dir

	$dir analyze [ set is_a_service 1 ] $language
	data::record $dir

    }

    return [ file::read_in $dir/[ set ${sub}::Report ] ]
}


## Creates a transaction pathname of a given type indexed by problem and team
## This is a version of the contest::transaction procedure
## It handles several transactions per second from the same user
## which is bound to happen on a service where the user is the service requester
proc service::transaction {type problem team} {
    variable ::Session::Conf
    
    set active data/contests/$Conf(contest)

    data::open $active

    set duration [ $active passed ]
 
    set random [ format {%08d} [ expr int(rand()*1e8) ] ]

    set path [ format {%s/%s/%08d_%s_%s%s} \
		       $active $type $duration $problem $team $random ]

    return $path
}




## return contest directory from identifer, if it is a valid one
proc service::get_contest {contest_id type} {

    set contest "data/contests/$contest_id"

    if { [ string equal $contest_id "" ] } {
	error [ format "Undefined contest ID" ]
    }

    if [ catch { data::open  $contest } ] {
	error [ format "Invalid contest ID: %s" $contest_id ]
    }

    if { ! [ $contest is_service $type ] } {
	set message  "Contest %s not configured as %s service"
	error [format $message $contest_id $type ]
    }

    if { ! [ $contest status "running" ] } {
	error [ format "Contest %s not running, check calendar" $contest_id ]
    }

    return $contest
}


## Returns an authorized team ID in given contest for this service requester
## If team does not exists in contest then it is automatically created 
proc service::get_authorized_team_id {contest} {


    set team_id [ get_requester_id ]
    
    data::open $contest/groups 

    set team [ $contest/groups search_team $team_id ]

    if { $team == {} } {
	regsub -all {_} $team_id {.} requester
	error "unauthorized service requester: $requester"
    }
    return [ file tail $team_id ]
}


# Returns a team ID using HTTP parameters: REMOTE_ADDR 
proc service::get_requester_id {} {
    global env

    set team_id ""
    if { [ info exists env(REMOTE_ADDR) ] } {
	lappend team_id $env(REMOTE_ADDR) 
    }

    regsub -all {\.} $team_id {_} team_id

    return $team_id
}


## Returns a Mooshak problem ID holding given LO
## This ID may be an URL of a remote LO or a Mooshak ID in this contest
proc service::get_problem {contest id} {

    set problems $contest/problems

    data::open $problems

    # Is this is an URL of a problem?
    if { [ regexp {http://} $id ] } {

	if { [set problem [$problems search $id "Original_location" ]] == {} } {

	    set problem [ $problems create_problem_from_url $id ]

	}
	# Or is this a local problem ID
    } elseif { [ set problem [ $problems search $id ] ] == {} } {
    
	error "Invalid problem ID: (not an URL and not an ID in this contest)"
    }

    return [ file tail $problem ]

}

proc service::load_problem {contest id} {
    

}


# Show original request data
proc service::show_request {request_type} {
    
    template::load erl.xml

    switch $request_type {

	GetReport {
	    upvar token token
	    template::record request_process_token
	}
	EvaluateSubmission {
	    variable ::file::TMP
	    upvar 1 program program
	    upvar 1 capability capability
	    upvar 1 problem_id lo

	    set userData [ get_user_data ]
	    template::record request_user_data

	    if { $program == "" } {
		set programCode {<!-- no program -->}
	    } else {
		set programCode [ file::read_in $TMP/$program ]
	    }
	    template::record request_process_evaluate
	}
    }

    return [ template::restore ]    
}



# all HTTP parameteres in request are echoed as userData
proc service::get_user_data {} {
    
    foreach name [ array names ::cgi::Field ] {
     set value $::cgi::Field($name)
	template::record userData
    }
    return [ template::restore ]
}


# Process a list capabilities request
proc service::list_capabilities {} {
    variable BIND_CHAR

    template::load erl.xml

    data::open data/contests

    set capabilities ""
    foreach service_handler [ data/contests service_handlers ] {
	data::open $service_handler/languages
	
	set service_name [ file tail $service_handler ]
	
	foreach language [ $service_handler/languages all ] {
	    
	    set features ""
	    set ls [ ::data::open $language ]
	    foreach  {var type comp}	$data::Attributes(Language) {
		if { ! [ string equal $type "text" ] } continue
		set feature_name $var
		if [ info exists ${ls}::${var} ] {
		    set feature_value [ set ${ls}::${var} ]
		}
		if { $feature_value != "" } {
		    append features \t[ template::formatting feature  ]\n\t
		}
	    }

	    set language_name [ file tail $language ]
	    set capability_id [ join \
				    [ list $service_name $language_name ] \
				    $BIND_CHAR ]
	    append capabilities \t[ template::formatting capability  ]\n
	}
	
    }

    return [ template::formatting capabilities  ]
}

## Current timestamp formated as XSD dateTime 
proc service::xsd_dateTime {} {
    return [ clock format [ clock seconds ]  -format "%Y-%m-%dT%H:%M:%S" ]
}

## Return variables values as CDATA section
proc service::debug variables {

    set data ""
    foreach var $variables {
	upvar $var $var
     	append data \n\t$var=[ set $var ]
    }
    return [ format {<![CDATA[ %s ]]>} $data]
}