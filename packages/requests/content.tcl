#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: content.tcl
#
## Manage the content of a directory or file
##

package provide content 1.0

package require data

namespace eval content {

    variable Content   Content.xml   ;## XML dir content description
    variable Manifest imsmanifest.xml;## IMS CP contest description (LO)
    variable Content2LO public_html/styles/Content2LO.xsl
    variable ArchiveType ".zip"	     ;## Archive type
    variable MaxAutoCreatedDirs	100  ;## Maximum number of auto created folders
    variable XSD_DIR public_html/xsd ;## Directory containing XML Schema files
    variable XSLTPROC	/usr/bin/xsltproc		;# xslt processor

    variable Define

    array set Define {
	UNCHANGED	0
	BACKUP		1
	UPDATE		2
    }
}

## Show right frame (data) 
## WARNING: This is a UNSAFE command 
proc content::content {{dir ""} {part ""} {update 0}} {

    switch $part {
	header	{ execute::header; content::show_header	$dir	$update }
	footer	{ execute::header; content::show_footer	$dir		}
	data	{ content::show_data	$dir		}
	default { execute::header; content::show 	$dir	$update }
    }
}

# Show the content of a directory or file
proc content::show {dir {update 0}} {
    variable ::Session::Conf
    global env 

    template::load

    classify $dir type class

    # process form and set redirection
    if [ string equal $type object ] {
	data::open $dir
	set update  [ expr $update || [ form $dir ] ]
	data::record $dir
    }

    # if refered by a HTML file show it again
    # upload of images in HTML descriptions
    if [ info exists env(HTTP_REFERER) ] {
	regexp [ format {%s?\?content\+(.*\.html)\+data$} $Conf(controller) ] \
	    $env(HTTP_REFERER) - dir
    } 	

    template::write frameset
}

proc content::show_header {dir {update 0}} {
    variable ::Session::Conf

    set dir  [ cgi::url_decode $dir ]
    set edir [ cgi::url_encode $dir ]

    template::load content/show

    classify $dir type class
    
    switch $type {
	object {     data::open $dir }
    }

    set menu_bar [ menu::bar $dir $class ]

    set on_load ""
    if $update {
	set on_load [ format {window.open('%s?data+%s','select');} \
			  $Conf(controller) $dir ]
    } 

    template::write head
}

# Show the content of a directory (or redirecting if in fact a file)
proc content::show_data {dir} {

    set dir  [ cgi::url_decode $dir ]

    template::load content/show
    
    classify $dir type class

    # show actual data
    switch $type {
	frozen {
	    execute::header 
	    set name 	[ freezer::type dir ]
	    set content	[ freezer::content $dir ]
	    template::write frozen
	}
	file {
	    show_file $dir
	} 
	object {
	    # PAGE SHOULD ONLY BE RECORDED AFTER AN UPDATE, RIGHT?    
	    execute::header 
	    set seg [ data::open $dir ]
	    show_dir $dir $class $seg
	}
	void {
	    execute::header
	    set guess [ guess_class $dir ]
	    template::write void
	}
    }
    
}

proc content::show_footer {dir} {
    set dir  [ cgi::url_decode $dir ]

    template::load content/show

    classify $dir type class

    set text [ translate::sentence $class ]    
    
    if { ! [ catch {  set link [ file link $dir ] } ] } {
	set dir [ format {%s -> %s} $dir $link ]
    }

    template::write foot
}


## Classify the given pathname (type and class)
proc content::classify {path type_ class_ } {
    upvar $type_ type
    upvar $class_  class 

    if [ freezer::frozen $path ] {
	set type frozen 	
	set class [ freezer::type $path ]	
    } else {
	if { ! [ file isdirectory $path ] } {
	    set type file
	    set class {}
	} elseif {  
		  ! [ file readable $path/$::data::Data_file ] ||
		  [ set class [ data::class $path ] ] == "" 
	      } {
	    set type void
	    set class {}
	} else {
	    set type object
	}
    }

}

## show a directory
proc content::inspect {dir} {
    variable ::data::Attributes
    variable ::data::Data
    variable ::data::Class

    if [ file isdirectory $dir ] {
	template::load

	execute::header	
	set seg [ data::open $dir ]
	set class $Class($dir)
	
	template::write head
	
	foreach  {var type comp}	$Attributes($class) {
	    set text  [ translate::sentence $var ]
	    if { [  catch { 
		set value [ set ${seg}::${var} ]
	    } ] } {
		# fields from previous versions may be undefined
		set value ""
	    }
	    
	    switch $type {
		fatal		{}
		warning		{}
		password	{}
		dir		{}
		dirs		{}
		fx		{	template::write file	    }
		default	{	template::write line	    }
	    }
	}
	template::write tail
    } else {
	show_file $dir
    }
}


## show a directory
proc content::show_dir {dir class seg} {
    variable ::data::Attributes

    set edir [ cgi::url_encode $dir ]

    template::write top

    foreach  {var type comp}  $Attributes($class) {
	puts [ show_dir_item $seg $class $dir $edir $var $type $comp ]
	
    }

    template::write bot
}


proc content::show_dir_item {seg class dir edir var type comp} {
    variable ::data::Data
    
    set text  [ translate::sentence $var ]
    regsub -all _ $text { } text
    if [ info exists ${seg}::${var} ] {
	set value [ set ${seg}::${var} ]
	# A similar line has been removed before
	regsub -all {\"} $value {\&quot;} value 
    } else {
	set value ""
    }
	
    
    if [ info exists ${class}::Tip($var) ] {
	set tip [ set ${class}::Tip($var) ]
    } else {
	set tip ""
    }

    if [ info exists ${class}::Help($var) ] {
        set help [ layout::help_text $text [ set ${class}::Help($var) ] ]
    } else {
	set help ""
    }
    
    # if comp has a wildcard then it must be expanded
    catch {
	if { [ set expand [ glob -nocomplain $dir/$comp/$value ] ] != "" } {
	    regexp ^$dir/(.*)/$value$ $expand - comp
	}
    }
    switch $type {
	choice - menu - ref - list {
	    set $Data($dir)::options($var) {}
	    set path [ get_path $dir $comp ]
	    set items [ get_items $dir $type $comp ]
	    if { [ string equal $type choice ] } {
		foreach {choice_var choice_type choice_comp } $comp {
		    if [ string equal $value $choice_var ] break
		}		
		set choice [ show_dir_item $seg $class $dir $edir $value $choice_type $choice_comp ]
	    } else {
		set items [ concat { "" } $items ]
	    }
	    set $Data($dir)::options($var) \
		[ mk_select_options $items $value ]		
	}
	date {
	    if { [ catch { set value [ date::from_sec $value ] } ] } {
		set value ""
	    }
	}
    }
    upvar #0 ${seg}::options options
    return [ template::formatting $type ]
}

## Get pathname. Absolute pathnames start with data/
proc content::get_path {dir comp} {

    if [ regexp {^data/} $comp ] {
	set path $comp
    } else {
	set path $dir/$comp
    }
}

## Return list of items from menu or ref
proc content::get_items {dir type comp} {

    switch $type {
	ref {
	    set items {}
	    foreach item [glob -nocomplain -type d [get_path $dir $comp ]/*] {
		lappend items [ file tail $item ]
	    }
	}
	choice {
	    set items {}
	    foreach {choice_var choice_type choice_comp} $comp {
		lappend items $choice_var
	    }
	}
	default {
	    set items $comp 
	}
    }
    return $items
}

## Return list of items from menu or ref
proc content::mk_select_options {items value} {

    set options ""
    foreach item $items {
	if { 
	    [ string equal $value $item ] || 
	    [ lsearch $value $item ] > -1 
	} {
	    set sel " selected"
	} else {
	    set sel ""
	}
	append options "<option$sel>$item</option>\n\n"
    }

    return $options
}


## Shows the content of a file
proc content::show_file {fx} {
   
    set re {(data/.+)/problems/(.*)/.*\.html?$}
    if [ regexp -nocase $re $fx - contest_path problem ] {
	# this is an HTML file (lets preprocess images)
	execute::header
	show_problem $contest_path $problem 

    } else {
	# this is a plain text or binary file (e.g. zip archive)

	if [ file readable $fx ] {
	    send_file_content_as_HTTP_response $fx
	} else {
	    execute::header
	    execute::report_error "Cannot read file" [ file tail $fx ]
	}
    }
}

## Send file content as HTTP response
proc content::send_file_content_as_HTTP_response {fx} {
    set fd [ open $fx r ]		
    puts [ format "Content-Type: %s" [ email::mime $fx ] ]
    puts ""
    fconfigure $fd -translation binary
    fconfigure stdout -translation binary
    fcopy $fd stdout
    close $fd
}


## Show HTML problem description
proc content::show_problem {contest_path problem} {
    variable ::Session::Conf

    template::load content/show_problem

    set path  $contest_path/problems/$problem
    set pb    [ data::open $path ]     
    set fx    [ set ${pb}::Description ]

    if { ! [ file readable $path/$fx ] } {
	execute::report_error "Problem description unavailable"
	return
    } else {
	set data  [ file::read_in $path/$fx ]

	# match images tags and replace them by Mooshak requests
	set criteria {(<img[^>]+src=)(\'|\")(?:\./)?([^\"\']+)(\'|\")}
        append subst [ format {\1\2%s+} $Conf(controller)?image ] \
	    [ file tail $path ] {+\3\4}	

	set description ""
	while { [ regexp -nocase {^(.*?)(<img[^>]+>)(.*)$} \
		      $data - pre tag data ] } {
	    append description $pre
	    if [ regexp -nocase 				\
		     {src=(?:\'|\")(?:\./)?([^\"\']+)(?:\'|\")}  \
		     $tag - imgfile ] {

		set image $path/images/$imgfile

		if [ file exists $image ] {
		    # image exists: replace by call to Mooshak 
		    regsub -all -nocase $criteria $tag $subst tag
		    append description $tag
		} else {
		    # missing image: replace by dialog for loading it
		    # (available just for admin, of course)
		    variable ::Session::Conf

		    if [ string equal $Conf(profile) admin ] {
			set name [ file tail $image ]
			append description [ template::formatting missing ]
		    }
		}
	    } else {
		append description [ format \
			 {<font color="red">%s: <code>%s</code></font>} \
			 [ translate::sentence "Missing attribute" ] src ]
	    }

	}
	append description $data
		   
	template::write
    }
}

## Load a CGI communication to data segment based on class
proc content::form {dir} {
    variable ::data::Attributes
    variable ::data::Class
    variable ::data::Data
    variable ::cgi::Field
    variable Define

    set changed $Define(UNCHANGED)
    set more_attributes $Attributes($Class($dir))
    while { $more_attributes != "" } {
	set attributes $more_attributes
	set more_attributes {}
	foreach  {var type comp} $attributes {

	    if { 
		[ string equal $type choice ]  &&
		[ info exists Field($var) ] 
	    } {
		data::more_attributes $comp $Field($var) more_attributes
		set this_change $Define(BACKUP)
	    }

	    if { [ info commands form_$type ] != "" } {
		set this_change [ form_$type $dir $var $comp ] 
	    } elseif { 
		      [ info exists Field($var) ]	&&
		      [ info exists $Data($dir)::${var} ]	&&
		      ! [ string equal [ set $Data($dir)::${var} ] $Field($var) ] 
		  } {
		# general case
		set this_change $Define(BACKUP)
	    } else {
		continue
	    }
	    if { $this_change && [info exists Field($var) ] } {
		namespace eval $Data($dir) [ list set $var $Field($var) ]
	    }
	    set changed [ expr $changed | $this_change ]
	}
    }

    if [ expr $changed & $Define(BACKUP) ] { backup::record $dir }

    return [ expr $changed & $Define(UPDATE) ]
}



## Processes date fields
proc content::form_date {dir var comp} {
    variable ::cgi::Field
    variable Define

    if { [ info exists Field($var) ] } {
	if { $Field($var) == "" || [ catch { 
	    set  Field($var) [ date::to_sec $Field($var) ] 
	} ] } {
	    set  Field($var) ""
	}    
	return $Define(BACKUP)
    } else {
	return $Define(UNCHANGED)
    }

}

## Processes password fields
## If authentication of current session is changed 
proc content::form_password {dir var comp} {
    variable ::cgi::Field
    variable ::Session::Conf
    variable ::data::Data
    variable Define

    if { [ cgi::field $var "" ] != "" } { 

	set Field($var) [ Session::crypt $Field($var) ]
	# if password being changed is in use ...
	if [ info exists $Data($dir)::${var} ] {
	    set user [ file tail $dir ]
	    set password [ set $Data($dir)::${var} ]
	    if { 
		[ string equal $Conf(profile) admin ]	&&
		[ string equal $Conf(user) $user ]	&&
		! [ string equal  correct 	       	       		\
			[ Session::check_password $Conf(authorization)  \
			      $password:Mooshak ] ] 
	     } {
		# ... redirect to top
		layout::window_open $Conf(controller)?admin _top
	    } 
	}
	return $Define(BACKUP)
    } else {
	return $Define(UNCHANGED)
    }
}

## Processes file upload fields
proc content::form_fx {dir var comp} {
    variable ::cgi::Field
    variable ::data::Data
    variable ::file::TMP
    variable Define

    if { [ info exists Field($var) ] && $Field($var) != "" } {		 
	set Field($var) [ file tail $Field($var) ]
	# if file lacks proper extensions then append it
	if { [ string compare [ file extension $Field($var) ] $comp ] != 0 } {
	    append Field($var) $comp
	}
	file rename -force $TMP/$Field($var)  $dir
	catch { file::safe_permissions $dir }

	return [ expr $Define(BACKUP) | $Define(UPDATE) ]
    } else {
	if { 
	    ! [ info exists $Data($dir)::$var ] || 
	    [ set $Data($dir)::$var ] == "" 
	} {
	    set Field($var) $var$comp		    
	    return $Define(BACKUP)
	} else {
	    return $Define(UNCHANGED)
	}
    }
}

## Processes option fields
proc content::form_choice {dir var comp} {
    variable ::cgi::Field
    variable ::data::Data
    variable Define
    
    set change 0
    if { [ info exists Field($var) ] } {
	set choice $Field($var)
	set change $Define(UPDATE)
    } elseif { 
	      [ info exists $Data($dir)::$var ] &&
	      [ set $Data($dir)::$var ] != ""
	  } {
	set choice [ set $Data($dir)::$var ]
    } else {
	set Field($var) [ set choice [ lindex $comp 0 ] ]
    }

    foreach {opvar optype opcomp} $comp {
	if { [ string equal $opvar $choice ] } {
	    if { [ info commands form_$optype ] != "" } {
		set change [ expr $change | \
				 [ form_$optype $dir $opvar $opcomp ] ]
	    }
	}
    }

    return $change
}

## Processes single directory  fields
proc content::form_dir {dir var comp} {
    variable ::cgi::Field
    variable ::data::Data
    variable Define

    set new $dir/[ dir_name $var ]

    remove_if_dangling $new
    
    if { ! [ file exists $new ] } { 
	data::new $new $comp
	file attributes $new -permissions g+w
	set Field($var) $var	;# var is not defined but should be recorded
	return [ expr $Define(BACKUP) | $Define(UPDATE) ]
    } else {
	return $Define(UNCHANGED)
    }
}

## Processes multiple directory fields
proc content::form_dirs {dir var comp} {
    variable ::cgi::Field
    variable ::data::Data
    variable Define
    variable MaxAutoCreatedDirs

    if { [ info exists Field($var) ] } {
	if { 
	    [ regexp {^[0-9]+$} $Field($var) ] && 
	    [ string trimleft $Field($var) 0 ] < $MaxAutoCreatedDirs
	} {
	    set number_of_dirs [ string trimleft $Field($var) 0 ] 
	    
	    set dir_name_list {}
	    set prefix [ get_prefix $comp ]
	    set number_of_digits [ expr int(log10($number_of_dirs))+1 ]
	    set dir_name_format "%s%0${number_of_digits}d"
	    for { set i 1 } { $i <= $number_of_dirs } { incr i } {
		lappend dir_name_list [ format $dir_name_format $prefix $i ]
	    }
	} else {
	    set dir_name_list $Field($var)
	}
	if [ catch { lindex $dir_name_list 0 } ] {
	    # check if its a proper list
	    layout::alert "Invalid list" $dir_name_list
	    return $Define(UNCHANGED)
	} else {
	    set changed $Define(UNCHANGED)
	    foreach dn $dir_name_list {
		set new $dir/[ dir_name $dn ]

		remove_if_dangling $new

		if { ! [ file exists $new ] } { 
		    data::new $new $comp
		    file attributes $new  -permissions g-w
		    set changed [ expr $Define(BACKUP) | $Define(UPDATE) ]
		} 
	    }
	    return $changed
	}
    } else {
	return $Define(UNCHANGED)
    }
}

# remove dangling links; only way to get ride of them
proc content::remove_if_dangling {link} {

    
    if { 
	! [ catch { set type [ file type $link ] } ]	&&
	[ string compare $type link ] == 0		&&
	! [ file exists $link ]
    } {
	file delete -force $link
    }

}

## Returns a file prefix based on the file type name
proc content::get_prefix {name} {

    regsub -all {[^A-Z]} $name {} prefix
    if { $prefix != "" }  {
	return $prefix
    } else  {
	return [ string toupper [ string index $name 0 ] ]
    }
}


## Reset a dir to its default content
## WARNING: This is a UNSAFE command 
proc content::reset {dir} {
    # $dir may be corrupted (hence the reset) and the backup will fail
    catch { backup::record $dir }

    if { [ set class [ guess_class $dir ] ] != "" } {
	catch {
	    data::new $dir $class
	    data::record $dir
	}
    }

    content::show $dir
}

# Guess class associated with $dir from its pathname
proc content::guess_class {dir} {
    
    if { [ set guess [ data::class $dir ] ] == "" } {
	foreach re { {/(\w+)$} {/(\w+)s/\w+$} } {
	    regexp {/(\w+)$} $dir - guess
	    set guess [ string totitle $guess ]
	    if { ! [ catch { package require $guess } ] } break
	}
    }    
    return $guess
}


## Valid directory name
proc content::dir_name {name} {
    regsub -all {[^0-9a-zA-Z_]} $name _ name
    return $name
}


## Processes a form for editing a file
proc content::edit {fx} {
    variable ::cgi::Field

    if { [ info exists Field(data) ] } {
	set data $Field(data)
    } else {
	set data "" 
	if { [ file readable $fx ] } {
	    set fd [ open $fx r ]
	    while { [ gets $fd line ] > -1 } {
		append data $line\n
	    }
	    catch { close $fd }
	}
    }
    set dir [ file dirname $fx ]

    template::load 
    template::write    

    file::permissions u+w $fx
    set fd [ open $fx w ]
    puts -nonewline $fd [ file::recode $data ]
    catch { close $fd }    
    file::permissions u+w $fx
}


## Produce dialog for exporting folder
proc content::export {dir} {
    variable ::Session::Conf

    set type [ data::class $dir ]
    set format [ layout::menu format { .zip .tar .tgz .tbz2 } $Conf(archive)  ]

    template::load 
    template::write    
}

## Export given dir 
proc content::exporting {dir} {
    variable ::Session::Conf

    if { [ set archive_type [ cgi::field format "" ] ] == "" } {
	variable ArchiveType

	set archive_type $ArchiveType
    } 

    set Conf(archive) $archive_type

    set create_dtd     [ cgi::field dtd 0 ]
    set create_archive [ cgi::field archive 0 ]

    if [ catch { 
	set data_file [ create_data_file \
			    $dir $create_dtd $create_archive $archive_type ]
    } msg ] {
	    layout::alert $msg
    }

    layout::window_close_after_waiting
    layout::window_open $Conf(controller)/$dir/$data_file

}

## Create an data file for exporting $dir with either:
##  1) just an XML file describing its content (no files)
##  2) an archive (zip, tar, tgz or tbz2 tgz) with XML manifesto and files
proc content::create_data_file {dir create_dtd create_archive archive_type} {
    variable Content    

    set fd [ ::open $dir/$Content w ]
    puts $fd [ xml::serialize $dir $create_dtd ]
    ::close $fd

    ## DEPRACATED: will be replaced by the BabeLO service
    ## set lo_files [ content::mk_lo_files $dir ]

    if { [ set files  [ xml::get_files ] ] == {} && ! $create_archive } {
	set data_file $Content
    } else {
	set data_file [ file rootname [ file tail $dir ] ]$archive_type
	set command   [ file::archive_command $data_file ] 

	set here [ pwd ]
	cd $dir
	if [ catch { 
	    eval exec $command $data_file $Content $files ;## $lo_files
	} msg ] {
	    cd $here    
	    error "Error creating $archive_type archive: $msg"
	} 
	cd $here
    }

    return $data_file
}



## DEPRECATED!!! BabeLO service will replace this function
## If $dir holds a Problem, create an IMS CP compliant manifest for archive
## and return a list of files to inlcude in media (zip archive)
proc content::mk_lo_files {dir} {
    variable Content
    variable Manifest
    variable Content2LO
    variable XSD_DIR
    variable XSLTPROC

    content::classify $dir dir_type dir_class

    set files {}

    switch $dir_class {
	Problem {

	    set problem [ data::open $dir ] 
	    variable ${problem}::Title
	    variable ${problem}::Difficulty
	    variable ${problem}::Program
	    variable ${problem}::Type


	    set contest [ data::open $dir/../.. ] 
	    variable ${contest}::Designation
	    variable ${contest}::Organizes
	    variable ${contest}::Start

	    if { $Program != "" } {
		set languages [ file::canonical_pathname $dir/../../languages ] 
		data::open $languages  
		set language_name [ $languages search $Program ]
		set language [ data::open $language_name ]
		variable ${language}::Compile
		variable ${language}::Execute
		variable ${language}::Name
		variable ${language}::Version

		set name [ file tail [file rootname $Program] ]
		set vars [ list                                         \
			       home		[ pwd ]			\
			       solution		$Program		\
			       file         	$Program                \
			       name         	$name     		\
			       extension    	[ file extension  $Program ] ]
		set compile [ file::expand $Compile $vars ]
		set execute [ file::expand $Execute $vars ]
	    } else {
		set compile ""
		set execute ""
		set Name ""
		set Version ""
	    }

	    regsub -all {\s} $Designation - designation
	    regsub -all {\s} $Title - title

	    set id [ format {urn:mooshak:%s-%s} $designation $title ]

	    if [ regexp {\d+$} $Start ] {
		set date [ clock format $Start -format "%Y/%m/%d %H:%M:%S" ]
	    } else {
		set date ""
	    }


	    set source $dir/$Content
	    set transform $Content2LO
	    set target	$dir/$Manifest

	    exec $XSLTPROC --noout				\
		--stringparam language		en 		\
		--stringparam title 		$Title		\
		--stringparam author 		$Organizes	\
		--stringparam date		$date		\
		--stringparam id 		$id		\
		--stringparam difficulty	$Difficulty	\
		--stringparam type		$Type		\
		--stringparam compile		$compile	\
		--stringparam execute		$execute	\
		--stringparam programmingLanguage $Name	\
		--stringparam programmingLanguageVersion $Version \
		-o $target $transform $source
	    
	    lappend files $Manifest
	    foreach xsd [ glob -nocomplain $XSD_DIR/*.xsd ] {
		set file [ file tail $xsd ]
		file copy -force $xsd $dir/$file 
		lappend files $file
	    }

	}
    }

    return $files
}


## Produce dialog for exporting folder
proc content::import {dir} {

    set type [ data::class $dir ]

    template::load 
    template::write    
}


## Import archive with XML manifesto containing contest data
proc content::importing {dir} {
    variable ::file::TMP
    variable ::cgi::Field
    variable ::Session::Conf

    set file $TMP/$Field(file)

    if { [ catch {
	import_file $dir $file
    } message ] } {

	layout::alert $message 

    } else {
	layout::window_open $Conf(controller)?data+$dir select
	layout::window_close
    }
}

proc content::import_file {dir file} {
    variable Content

    if [ regexp {\.xml$} $file ] {
	set archive ""
	set data [ file::read_in $file ]
    } else {
	set archive $file
	# extract just XML content to memory (without creating file)    
	set command [ file::unarchive_command $archive  1 ]
	set data [ process::exec_in_dir "$command $archive $Content" $dir ]
    }

    set doctype [ xml::doctype $data ]
    if [ string equal $doctype [ data::class $dir ] ]  {
	cleanup $dir
	extract $dir $archive $file $data
    } elseif { [ lsearch [ data::subclasses $dir ] $doctype ] > -1 } {
	set dir $dir/[ file tail  [ file rootname $file ] ]
	data::new $dir $doctype
	extract $dir $archive $file $data
    } else {
	layout::alert "XML file doesn't match the class of this folder"
    } 

}



# cleanup dir, i.e. remove and files and directories
proc content::cleanup {dir} {
    if { [ set files [ glob -nocomplain $dir/* ] ] != "" } {
	eval file delete -force -- $files
    }
}

## Extract $archive into $dir with content description in $data
proc content::extract {dir archive file data} {
    variable Content

    if { $archive == "" } {
	file rename -force $file $dir/$Content
    } else {
	set command [ file::unarchive_command $archive  0 ]
	process::exec_in_dir "$command $archive" $dir	    
    }

    if [ file readable $dir/$Content ]  {	    
	file::safe_permissions $dir	    
	if [ xml::has_dtd $data ] {
	    xml::validate $dir/$Content
	}
	xml::unserialize $dir $data
    } else {
	layout::alert "XML content description file not found"
    } 
    file delete -force $file

}

