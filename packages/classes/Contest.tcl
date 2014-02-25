# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Contest.tcl
# 
## Management of a contest as a whole. Although several contests may exist
## in Mooshak (under the "contests" directory) at most one is active.
## The active contest is linked to $ActiveContest path.
##
## Contests may be in one of 3 possible states, reflected by the <b>Status</b>
## variable. The possible states are:
##
## <ul>
##	<li>created:
##		<ul>
##			<li>only available in admin</li>
##		</ul>
##	 </li>	
##	<li>ready:   
##		<ul>
##			<li>teams, judges, runners and guests can login</li>
##		</ul>
##	</li>
##	<li>running: 
##	<ul>
##		<li>submissions accepted</li> 
##		<li>problem descriptions shown</li>
##		<li>teams, judges, runners and guests fully operational</li>
##	</ul></li>
##
##	<li>finished:
##		<ul>
##			<li>teams, judges, runners and guests can login</li>
##			<li>questions accepted and answered</li>
##			<li>printouts accepted</li>
##		</ul>
##	</li>
##	<li>concluded:
##		<ul>
##			<li>only available in admin</li>
##		</ul>
##	 </li>	
## </ul>
##	
## These status is controled by 4 date variables that control the moment
## in which the contest <b>automatically</b> changes its status. These
## variables are
##
## <ol>
##	<li>Open 	(created -> ready)</li>
##	<li>Start	(ready -> running)</li>
##	<li>Stop	(running -> finished)</li>
##	<li>Close	(finished -> concluded)</li>
## </ol>


package provide Contest 1.0

package require data

namespace eval Contest {

    variable Types	;## list of contest types
    variable TypeInfo	;## Array with contest type definitions

    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    variable Policies	;# list of available classification policies

    variable CACHE_FILE pending.tcl

    set Policies {}
    foreach policy [ lsort [ glob -nocomplain packages/policies/*.tcl ] ] {
	lappend Policies [ file rootname [ file tail $policy ] ]
    }

    array set Tip {
	Designation	"Contest official name"
	Organizes	"Name of person or institution organizing the contest"
	Email		"Mail address used as sender in messages to teams"

	Open		"Date/time to open the contest"
	Start		"Date/time to start the contest"
	Stop		"Date/time to stop the contest"
	Close		"Date/time to stop the contest"
	HideListings	"Minutes before end of contest to hide results"

	Policy		"Evaluation and classification policy"
	Virtual		"Is being used as a virtual contest"
	Register	"Accept guest registration and send authentication by email"

	Service		"What kind of services are exposed to remote programs"
	Prepare		"Prepare contest to start"
	Run-all-checks... "Produces report from checking all sub-folders"
	Type...		"Configures several fields in this folder and sub-folders with pre-defined values"

    }

    array set Help {
	Policy {
	    The grading of submissions and ranking of teams depends on 
	    policies. Different types of contests will use different policies,
	    such as  ICPC and IOI. 

	    The EXAM policy was designed for using Mooshak as a pedagogical 
	    tool. 

	    New policies can be easily added to Mooshak such as the 
	    SHORT policy that uses program size rather than time to rank 
	    submissions.
	    
	    Policies are automatically set when a contest type is defined
	    using menu command Contest | Type ...
	}
	Virtual {
	    In a virtual contest teams start competing in the moment they
	    first login, independently of Start and End times. The team's
	    time is automatically adjusted in relation to the contest's  
	    start time. Submissions, questions, etc, will use this
	    adjusted time. Listings will hide entries that occured after 
	    the ajusted time.

	}
	Register {
	    Use this field to allow users to register themselves as teams 
	    using the Register button in the login dialog of Mooshak.
	    Users will be able to choose the name and group of their teams
	    and will receive the authentication data trough email.
	}
	Service {
	    This contest may expose automatic evaluation and/or its content
	    (problems) as REST web services. Use this field to enable remote
	    requests to these services in this contest.
	}
    }


    set Types  {Default	ICPC	IOI	Short	Exam  Assign	Quiz	Service}
    set TypeInfo {
.	     Policy      
		icpc	icpc	ioi	short	exam  exam	quiz	icpc
.     HideListings     
		{}	60	300	{}	{}    {}	{}	{}
.	     Virtual	
		{}      {}      {}      {}      yes   {}	yes	{}
.       Service	
		none	none	none	none	none	none	none	both
.	challenge	
		-	-	-	-	-     -		quiz	-
printouts    List-Pending     
		yes	no	no	no	no    no	no	no
balloons     List-Pending
		yes	no	no	no	no    no	no	no
submissions  Give_feedback
		{}	{}	none	{}	{}    none	{}	{}
submissions  Show_errors
		C+R	{}	C	C+R	all   all	{}	all
submissions  Default_state
		pending	pending	final	pending	final final	final	final
submissions  Multiple_accepts 
		no	no	yes	yes	no    yes	no	yes
languages    MaxProg	
      		-         -	-	-	-     9000000	-	-
    }
}

Attributes Contest \
    [ list 						\
      Type	status	{}				\
    Status	status	{}				\
    Fatal	fatal	{}				\
    Warning	warning {}				\
							\
    Designation	text	{}				\
    Organizes	text	{}				\
    Email	text	{}				\
							\
    Open	date	{}				\
    Start	date	{}				\
    Stop	date	{}				\
    Close	date	{}				\
							\
    HideListings text	{}				\
							\
    Policy	menu	$Contest::Policies		\
    Virtual	menu	{ yes no }			\
    Register	menu	{ yes no }			\
    Service	menu	{ none evaluation content both }		\
							\
    Notes	long-text {}				\
							\
    groups	dir	Groups				\
							\
    challenge	choice	{ problems dir	Problems quiz dir Quiz }	\
							\
    submissions	dir	Submissions			\
    questions	dir	Questions			\
    printouts	dir	Printouts			\
    balloons	dir	Balloons			\
    languages	dir	Languages			\
    users	dir	Users			\
    ]


## On creation set Designation as the directory name
Operation Contest::_create_ {} {

    set Designation [ file tail ${_Self_} ]

    data::record ${_Self_}
}

## Update contest: checks attributes and sets status
Operation Contest::_update_ {} {

    set Fatal ""
    set Warning ""

    if { [ info tclversion ] < 8.6 } {


	set message "Listing cache disabled:"
	append message "tclsh version is inferior to 8.6:"
	check::record Warning var $message [ info tclversion ]
    }


    foreach {attr type} { Designation Fatal Organizes Warning Email Warning } {
	check::attribute $type $attr
    }

    foreach attr { Start Stop } {
	#check::attribute Fatal $attr {^[0-9]+$}
    }

    switch $Type {

	Quiz {}

	default {

	    foreach dir {groups  problems languages} {
		check::attribute Fatal $dir dir
	    }

	    foreach dir {submissions questions printouts balloons} {

		check::attribute Warning $dir transactions
	    }

	}
    }


    set Status [ ${_Self_} status ]

    return 0
}


Operation Contest::run-all-checks ? {
    ${_Self_} check
}

## Dialogue for defining type of contest. Sets a policy and
## several properties in the contest object
Operation Contest::type ? {
    variable Types
    variable TypeInfo

    template::load
    set self ${_Self_}
    set span [ llength $Types ]
    template::write head

    foreach type $Types {

	if { [ info exists Type ] && [ string equal $type $Type ] } {
	    set checked " checked"
	} else {
	    set checked ""
	}
	template::write type
    }

    template::write mid
    set n 0
    foreach [ concat dir name $Types ] $TypeInfo {
	layout::toggle_color n color
	
	template::write attr_head
	foreach type $Types {
	    set value [ set $type ]
	    template::write attr_value
	}
	template::write attr_foot	
    }
    template::write foot
    
}

## Continuation from type setting dialog.
## Sets pre-defined field values according to defined contest type
## Non existing folders are created and initialized
Operation Contest::set_type {} {
    variable Types
    variable TypeInfo
    variable ::Session::Conf

    set Type [ cgi::field type ? ]

    foreach [ concat dir name  $Types ] $TypeInfo {

	set value [ set $Type ]
	if [ string equal $value - ] continue
	if [ string equal $dir "." ] {
	    set $name $value 

	    if { [ string equal ${name} "challenge" ] } {
		data::new $value [ string totitle $value ]
		set $value {}
	    }

	} else {
	    set path ${_Self_}/$dir
	    set po [ data::open $path ]
	    
	    # if $dir doesn't exist initialize it
	    set data $path/$::data::Data_file 
	    if { ! [ file exists $data ] || [ file size $data ] == 0 } {
		data::record $path 
	    }

	    # check for possible errors in type definition
	    if { ! [ info exists ${po}::${name} ] } {
		layout::alert "Undefined field" $dir:$name 
	    }
	    if { [ string equal ${name} Show_errors ] } {
		switch $value {
		    all	{	set value [ lrange $Submission::Results 1 11 ]}
		    C	{	set value [ lindex $Submission::Results 8 ] }
		    R	{	set value [ lindex $Submission::Results 7 ] }
		    C+R {	set value [ lrange $Submission::Results 7 8 ] }
		}
	    }

	    set ${po}::${name} $value 
	    data::record $path
	}
    }

    data::record ${_Self_}
	
    layout::window_open $Conf(controller)?content+${_Self_} work

    layout::window_close
    
}

## Returns true if guest can register in contest, false otherwise (default)
Operation Contest::registrable {} {

    if { [ info exists Register ] && [ string equal $Register yes ] } {
	return 1
    } else {
	return 0
    }
}


## Should we hide listings from everyone but admin and judges?
## Listing are hidden if $HideListing is defined and is time to hide!
## Use flag $blackout to control hiding  during blackouts
Operation Contest::hide_listings {message_ {profile {}} {blackout 1}} {
    upvar 3 $message_ message
    variable ::Session::Conf

    set now [ clock seconds ]
    set message ""
    set limit -1

    # if $HideListings is the empty string the following expr is invalid
    if { $blackout && [ info exists HideListings ] && $HideListings != "" } {
	if { [ expr \
		   ! [ string equal $Conf(profile) admin ]	&& \
		   ! [ string equal $Conf(profile) judge ]	&& \
		   [ regexp {^[0-9]+$} $HideListings ]	&& \
		   [ regexp {^[0-9]+$} $Stop ]		&& \
		   $Stop - $now < $HideListings * 60 ] } {

	    set freeze [ expr $Stop - ($HideListings * 60) ]
	    set message [ format "Listing frozen at %s" \
			      [ date::from_sec $freeze ] ] 
	    
	    if { [ string equal $profile team ] } {
		append message						\
		    [ format " - showing only new submissions from %s"	\
			  $Conf(user) ]
	}


	    set limit [ expr $Stop - $Start - ($HideListings * 60)]
	} 
    } elseif { [ info exists Virtual ] && [ string equal $Virtual yes ] } {
	
	if { [ set team [ contest::team_path ] ] != "" } {
	    data::open $team
	    set limit [ $team passed_from_login $now ]
	}
    }

    return $limit
}


## Propagates cheks to all sub-directories 
## producing a report if flag $output is set (default)
Operation Contest::check {{output 1}} {

    check::head $Designation [ ${_Self_} remaining ]
    check::vars Designation

    foreach d { groups  problems } {
	set sdir ${_Self_}/$d
	if { ! [ file isdirectory $sdir ] } {
	    [ format {%s: <code>%s</code>} \
		  [ translate::sentence "Missing directory" ] $sdir ]
	    continue
	}
	data::open $sdir
	$sdir check
    }

    check::dir_start 1
    foreach d { languages submissions questions printouts balloons } {
	set sdir ${_Self_}/$d
	if { ! [ file isdirectory $sdir ] } {
	    check::report_error Fatal  "Missing directory" $sdir
	    continue
	}
	data::open $sdir
	$sdir check
    }
    check::dir_end 1

    check::foot    
    
    if $output { template::show }
}

## Prepare contest to start
Operation Contest::prepare ! {

    ${_Self_} prepare_me
    
    layout::alert "Contest prepared"

    content::show ${_Self_}
}

## Cleans directories with transctions and makes other preparetions
Operation Contest::prepare_me {} {


    if [ ${_Self_} status running ] {
	layout::alert "Contest running" "nothing done"

    } else {

	foreach name { submissions questions printouts balloons } {
	    set dir ${_Self_}/$name
	    if { ! [ file isdirectory $dir ] } {
		continue
	    }
	    data::open $dir
	    $dir prepare
	}
    
	data::record ${_Self_}
    }

    content::show ${_Self_}
}

## Cheks if this contest can be used as a REST service of given type
Operation Contest::is_service {{type "both"}} {

    if {
	[ info exists Service ]					&&
        ([ string equal $Service  $type ] 		|| 
	 	( $Service != ""  		&& 
		  ! [ string equal $Service "none" ]
		)
	)
    } {
	return 1
    } else  {
	return 0
    }
}


## Checks or returns contest status
## Without arguments returns contest status
## With a list of arguments checks if is in on of those status
Operation Contest::status {{guesses ""}} {
    
    set now [ clock seconds ]    
    set status created

    if { [ info exists Virtual ] && [ string equal $Virtual yes ] } {
	    set status "running virtually"
    } else {
	if { [ regexp {^[0-9]+$} $Open ] && $Open <= $now    } {
	    set status ready
	}
	if { [ regexp {^[0-9]+$} $Start ] && $Start <= $now  } {
	    set status running
	}
	if { [ regexp {^[0-9]+$} $Stop ] && $Stop <= $now    } {
	    set status finished
	}
	if { [ regexp {^[0-9]+$} $Close ] && $Close <= $now  } {
	    set status concluded
	}
    }
    
    if { $guesses == "" } {
	return $status
    } else {
	return [ expr [ lsearch $guesses $status ] > -1 ]
    }
}

## Convinience operation: message explaining why something is not allowed
Operation Contest::not_allowed {what} {

    return [ format [ translate::sentence "%s NOT allowed, contest %s" ] \
		 [ translate::sentence $what ] 				 \
		 [ translate::sentence [ ${_Self_} status ] ] ]
}


## Returns a colored string showing the remaining time
## As the remaing time reaches zero the color becomes more red
proc Contest::remaining {} {

    data::attributes

    set now [ clock seconds ]       

    if { [ info exists Virtual ] && [ string equal $Virtual yes ] } {

	# virtual contest
	if { [ set team [ contest::team_path ] ] != "" } {	    
	    data::open $team
	    set now [ expr [ $team passed_from_login $now ] + $Start ]
	} elseif { ! [ regexp {^[0-9]+} $Start ] } {
	    return [ translate::sentence "No start time in VC" ]
	} elseif { ! [ regexp {^[0-9]+} $Stop ] } {
	    return [ translate::sentence "No stop time in VC" ]
	} else {
	    set now $Start
	} 	    

    } else {

	# regular contest: check if its during contest

	if { ! [ regexp {^[0-9]+} $Start ] } {
	    return [ translate::sentence "The contest did not start" ]
	} elseif { ! [ regexp {^[0-9]+} $Stop ] } {
	    return [ translate::sentence "Contest running" ]
	} elseif { [ set remaining [ expr $Start - $now ] ] > 0 } {
	    # time to start
	    foreach {hours min sec} \
		[ split [ date::from_long_sec $remaining ] : ] {}	
	    set remaining [ format {%s:%s %s} $hours $min \
				[ translate::sentence "to start"] ]
	    
	    return  $remaining
	}	    

    }	

    if { [ set missing [ expr $Stop - $now ] ] > 0 } {
	# time to start
	set per [ expr 255 - 255 * $missing / ($Stop - $Start) ]
	set color [ format "#%02x0000" $per  ]
	
	foreach {hours min sec} \
	    [ split [ date::from_long_sec $missing ] : ] {}
	set end [ translate::sentence "to end"]
	set remaining [ format {%s:%s %s} $hours $min $end ]
	
	return "<font color='$color'>$remaining</font>"
    } else {
	return [ translate::sentence "Contest ended" ]
    }
}

## Returns the number of seconds since the contest started
Operation Contest::passed {} {

    set now [ clock seconds ]
    if { [ info exists Virtual ] && [ string equal $Virtual yes ] } {	
	if { 
	    [ set team [ contest::team_path ] ] != ""	&&
	    ! [ catch { data::open $team } ]
	} {
	    return  [ $team passed_from_login $now ]
	} else {
	    return 0
	}
    } elseif { [ regexp {^[0-9]+} $Start ] } {
	return [ expr ($now - $Start)  ]
    } else {
	return 0
    }

}


## Adjust time in contest, considering virtual time
Operation Contest::adjust_time {moment} {

    set now [ clock seconds ]
    if { 
	[ set passed [ ${_Self_} passed ] ] > 0 &&
	[ regexp {^[0-9]+} $Start ] 
    } {
	return [ expr $now - $passed + $moment - $Start ]
    } else {
	return $moment
    }
}


## Moment when this content starts 
Operation Contest::start {} {

    set now [ clock seconds ]
    if { [ set passed [ ${_Self_} passed ] ] > 0 } {

	return [ expr $now - $passed ] 
    } elseif { [ regexp {^[0-9]+} $Start ] } {
	return $Start
    } else {
	return 0
    }

}

## Moment when this content will end
Operation Contest::stop {} {

    set now [ clock seconds ]
    if { [ set passed [ ${_Self_} passed ] ] > 0  &&       
	 [ regexp {^[0-9]+} $Start ] &&
	 [ regexp {^[0-9]+} $Stop  ]
     } {
	return [ expr $now - $passed + ($Stop-$Start)] 	
    } else {
	return 0
    }    
}


## Returns the duration of the contest seconds 
Operation Contest::duration {} {

    if { [ regexp {^[0-9]+} $Start ]  && [ regexp {^[0-9]+} $Stop ] } {
	return [ expr $Stop - $Start ]
    } else {
	return inf
    }
}


########################################################
## List of unanswered questions of non validated submissions
Operation Contest::pending {profile} {
    global REL_BASE
    
    set problem [ cgi::field problem "" ]
    set team	[ contest::team ]
    set message ""
    set candidates {}
    array set all {}

    listing::header message

    # just admin e judge
    if [ regexp {^admin|judge$} $profile ] {
	pending_candidates submissions	${_Self_} $problem $team candidates all
    } 

    # printouts (admin and judge only if requested)
    if { [ string equal $profile runner ]
	 || ( [ set imp [ data::open ${_Self_}/printouts ] ] != {} &&
	      [ info exists ${imp}::List-Pending ] &&
	      [ string equal [ set ${imp}::List-Pending ] yes ]  )
     } {
	pending_candidates printouts	${_Self_} $problem $team candidates all

    } 
    
    # balloons (admin and judge only if requested)
    if { [ string equal $profile runner ]
	 || ( [ set blp [ data::open ${_Self_}/balloons ] ] != {} &&
	      [ info exists ${blp}::List-Pending ] &&
	      [ string equal [ set ${blp}::List-Pending ] yes ]  )
    } {
	pending_candidates balloons	${_Self_} $problem $team candidates all
    }

    set pendings [ check_pendings ${_Self_} $candidates ]

    listing::part pendings pages last m

    foreach sub $pendings {
	data::open $sub
	set type [ file tail [ file dirname $sub ] ]	
	set n [ expr [ llength $all($type) ] - [ lsearch $all($type) $sub ] ]

	$sub listing_line $n $m $profile

	incr m -1
    }

    listing::footer [ incr m ] $pages $pendings
}

## Check what is pending from list of candidates
## Use a chache to avoid reading everything from disk
proc Contest::check_pendings {dir candidates} {
    package require cache

    variable ::cache::CACHE_DIR_NAME
    variable CACHE_FILE

    set cache_dir  $dir/$CACHE_DIR_NAME
    set cache_file $cache_dir/$CACHE_FILE

    file mkdir $cache_dir

    cache::restore $cache_file

    set fd [ cache::reopen $cache_file ]

    set pendings {} 
    
    foreach sub $candidates {
	
	set id [ file tail $sub ]

	if { 
	    ! [ info exists pending($id) ]
	} {
	    set pending($id) 0			 
	    catch {
		data::open $sub
		if [ $sub new ] { 
		    set pending($id) 1
		}
	    }
	}
	if $pending($id) { lappend pendings $sub }
    }

    puts $fd [ format {array set pending %s} [ list [ array get pending ] ] ]

    cache::replace $fd

    return $pendings
}

# Patch (add a line) to the cache file
# This is an alternative to cache invalidation
Operation Contest::patch_cache {sub state {type Submission}} {
    package require cache

    variable ::${type}::States
    variable ::cache::CACHE_DIR_NAME
    variable CACHE_FILE

    set cache_dir  ${_Self_}/$CACHE_DIR_NAME
    set cache_file $cache_dir/$CACHE_FILE

    file mkdir $cache_dir

    set id  [ file tail $sub ]
    set val [ string equal $state [ lindex $States 0 ] ]

    set line [ format {set pending(%s) %d} $id $val ]

    cache::patch $cache_file $line 
}

# Invalidate cache used to evaluate pendings
# Needed when submission is reverted to pending
Operation Contest::invalidate_cache {} {
    package require cache

    variable ::cache::CACHE_DIR_NAME
    variable CACHE_FILE

    set cache_dir  ${_Self_}/$CACHE_DIR_NAME
    set cache_file $cache_dir/$CACHE_FILE

    file mkdir $cache_dir
# should lock before removing?
    file delete -force $cache_file
}



## Pending candidates from a given $type in $directory
## Use $problem and $team to restrict pendings
## Concat pendings candidates in list with name $candidates_
## Save list with all pendings of this type in array with name $all_ 
proc Contest::pending_candidates {type dir problem team candidates_ all_} {
    upvar $candidates_ candidates
    upvar $all_ all

    set pending_type [ listing::restrict $dir/$type ] 
    switch $type {
	pending {
	    set sorted_from_type [ lsort -decreasing $pending_type ]
	}
	default {
	    set sorted_from_type \
		[ lsort -command \
		      [ list listing::cmp \
			    [ list _${problem}_ _${team}\$ ] ] \
		      $pending_type ]
	}
    }
    set candidates [ concat $candidates $sorted_from_type ]
    
    set all($type) [ lsort -decreasing [ listing::unrestrict \
						$dir/$type ] ]
}


## Returns contest policy. ICPC is the default
## This procedure implements a policy factory
Operation Contest::policy {} {
    
    if { $Policy == "" } {
	set policy  icpc
    } else {
	set policy  $Policy
    }
    
    namespace eval :: [ list source packages/policies/$policy.tcl ]
    return $policy

}
