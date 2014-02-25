#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file:  xml.tcl
# 
## Serializes Mooshak's folfers into XML data and vice-versa.
## Implements a simple XML parser and generator
## XML data is standalone and may include a DTD in the prologue
##
## Some considerations about Mooshak XML representation 
## <ul>
##	<li> MAY have a DTD in the prologue</li>
##	<li> defines a default XML namespace </li>
##	<li> defines a seconds namespace for handling clear text passwords</li>
##	<li> defines an XML element for each folder class </li>
##	<li> defines a xml:id for each element (usable without validation)</li>
##	<li> encodes string fields of folders using  XML attributes</li>
##	<li> sub-folders are mapped to sub-elements</li>
##	<li> doesn't have text elements</li>
## </ul>
##
## TODO: long-text in CDATA sections
## TODO: expand namespace prefixes to URIs (ct: is hardwired to code)

package provide xml 1.0

namespace eval xml {
    variable MOOSHAK_NAMESPACE 		\
	"http://www.ncc.up.pt/mooshak/"
    variable MOOSHAK_NAMESPACE_CLEAR_TEXT_PASSWORD \
	"http://www.ncc.up.pt/mooshak/clear_text_password"
    variable SAFE_ID_PREFIX  "::SAFE:ID:PREFIX::"
    variable MAX_ATTR_SIZE 10000     ;## Run away attribute values
    variable CHARACTER_ENCODING 	ISO-8859-1
    variable UNDEF 	""    	     ;## Value of undefined elements/attributes
    variable TabSkip	5	     ;## tab skil (in chars) used in XML ouput
    variable Files	{}	     ;## list of files in serialization 
    variable XMLLINT	/usr/bin/xmllint


    namespace export has_dtd	     ;## data contains a DTD ?
    namespace export validate	     ;## validate file with DTD
    namespace export doctype	     ;## returns document's type
    namespace export serialize	     ;## perobjs to XML
    namespace export deserialize     ;## XML to perobjs 
    namespace export get_files	     ;## filnames in last serialization
    namespace export check_embed_xml ;## check tags embed in given text
}

## validate XML file using xmllint and the documents DTD
proc xml::validate {fx} {
    variable XMLLINT

    if [ file executable $XMLLINT  ] {
	exec $XMLLINT --valid --noout $fx
    }
}

## returns true if data contains a DTD
proc xml::has_dtd {data} {

    return [ regexp {<!DOCTYPE\s+\w+\s+} $data ]
}

proc xml::doctype {data} {

    if [ regexp {<!DOCTYPE\s+(\w+)\s+} $data - myclass ] {
	# doctype inferred from DTD
    } elseif [ regexp {<(\w+)(\s+|>)} $data - myclass ] {
	# first tag in data
    } else {
	error "No document type in XML file"
    }

    return $myclass
}


## Serialize Mooshak data into an XML string
proc xml::serialize {dir {dtd 0}} {
    variable MOOSHAK_NAMESPACE
    variable CHARACTER_ENCODING
    variable Files

    set Files {}
    set top_attributes [ format { xmlns="%s"} $MOOSHAK_NAMESPACE ]

    set xml [ format {<?xml version="1.0" encoding="%s" standalone="yes"?>} \
		  $CHARACTER_ENCODING ]
    append xml \n
    if $dtd {
	append xml [ generate_dtd [ data::class $dir ] ]
    }
    append xml [ serialize_dir $dir $dir $dtd $top_attributes ]
    
    return $xml
}

## return file references in last XML serialization
proc xml::get_files {} {
    variable Files

    return $Files
}

## Serialize given dir in XML
proc xml::serialize_dir {dir base dtd {extra ""}} {
    variable ::data::Attributes
    variable ::data::Class
    variable ::data::Data
    variable TabSkip
    variable Files
    variable MAX_ATTR_SIZE

    data::open $dir

    regexp "^${base}/?(.*)$" $dir - rel
    set top [ file tail $base ]
        
    set t0 [ expr [ llength [ split $rel / ] ] * $TabSkip ]
    set t1 [ expr $t0 + $TabSkip ]
    set t2 [ expr $t1 + $TabSkip ]

    if { [ set id [ path2id $top $rel ] ] != "" } {
	append extra [ format { xml:id="%s"} $id ]
    }
    set xml [ format {%*s<%s%s} $t0 {} $Class($dir) $extra ]

    set children ""
    set note ""
    foreach  {var type comp}	$Attributes($Class($dir)) {
	if [ info exists $Data($dir)::${var} ] {
	    set value [ set $Data($dir)::${var} ]
	    if { [ string length $value ] > $MAX_ATTR_SIZE } {
		set value [ string range $value 0 $MAX_ATTR_SIZE ]
		append value ...TRUNCATED...
	    }
	    set value [ protect_pcdata $value ]
	} else {
	    # if field is not set (maybe from an old version) defaults to ""
	    set value ""
	}

	if [ string equal $type choice ] {
	    add_attribute xml $var $value $dtd $t2
	    set choice $value
	    foreach {var type comp} $comp {
		if [ string equal $choice $value ] break
	    }
	}	

	switch $type {
	    dir {
		append children [ serialize_dir $dir/$var $base $dtd ]
	    }
	    dirs {
		foreach ndir [ glob -type d -nocomplain $dir/* ] {
		    append children [ serialize_dir $ndir $base $dtd ]
		}
	    }

	    fx {
		set path [ join [ concat $rel $value ] / ]
		if { $value != "" && [ file readable $base/$path ] } {
		    lappend Files $path
		}
		add_attribute xml $var $value $dtd $t2
	    }
	    password {
		append note [ format "<!-- use ct:%s to insert password in plain text instead of hash -->\n" $var ]
		add_attribute xml $var $value $dtd $t2
	    }
	    default {
		add_attribute xml $var $value $dtd $t2
	    }
	}
    }
    if { $children == "" } {
	append xml "/>\n"
    } else {
	append xml ">\n"
	append xml $children
	append xml [ format "%*s</%s>\n" $t0 {} $Class($dir) ]
    }
    return $xml$note
}

## add an attribute to XML element, if necessary
proc xml::add_attribute {xml_ var value dtd t2} {
    upvar $xml_ xml


    if { $value == "" && $dtd } {
	## if value is "" and a DTD is in use the it is #IMPLIED
    } else {
	regsub -all \" $value {&quot;} value
	append xml [ format "\n%*s%s=\"%s\"" $t2 {} $var $value ]
    }
}


## Generates a DTD for a given folder class
proc xml::generate_dtd {top_class} {
    variable ::data::Attributes
    variable ::data::Class
    variable MOOSHAK_NAMESPACE 		
    variable MOOSHAK_NAMESPACE_CLEAR_TEXT_PASSWORD 


    set pending_classes [ list $top_class ]
    set processed_classes {}


    set dtd [ format "<!DOCTYPE %s \[" [ lindex $pending_classes 0 ] ]
    append dtd \n

    set  attributes {}
    lappend attributes xmlns 	CDATA \
	[ format "\#FIXED \"%s\"" $MOOSHAK_NAMESPACE ]
    lappend attributes xmlns:ct CDATA \
	[ format "\#FIXED \"%s\"" $MOOSHAK_NAMESPACE_CLEAR_TEXT_PASSWORD ]
    while { $pending_classes != {} } {
	set element_type  [ lindex $pending_classes 0 ]
	set pending_classes [ lrange $pending_classes 1 end ]
	
	package require $element_type
	
	append dtd [ format "\t<!ELEMENT %s " $element_type ]
	set pattern {}

	lappend attributes  xml:id ID "\#IMPLIED"

	foreach  {var type comp}	$Attributes($element_type) {
	    if { [ info commands generate_dtd_$type ] != "" } {
		generate_dtd_$type $var $comp
	    } else {
		generate_dtd_default $var $comp
	    }
	}    
	if { $pattern == {} } {
	    append dtd "EMPTY>\n"
	} else {
	    append dtd [ format "(%s)>\n" [ join $pattern {, } ] ]
	}
	append dtd [ format "\t\t<!ATTLIST %s" $element_type ]
	foreach {attribute type default} $attributes {
	    append dtd [ format "\n\t\t\t%-15s %-8s %s" \
			     $attribute $type $default ]
	}
	append dtd ">\n"
	set attributes {}
    }
    
    append dtd "\]>\n"
    return $dtd
}

## Generates DTD for choices in a given folder class
## Choices must alternate between dir/dirs (mapped into xml elements)
## or other types (mapped into xml attributes), otherwise raises an exception.
proc xml::generate_dtd_choice {var choices} {
    upvar processed_classes processed_classes
    upvar pending_classes pending_classes
    upvar pattern pattern
    upvar attributes attributes


    # must create attribute for choice selector
    lappend attributes $var CDATA \#IMPLIED

    # instead of passing pattern as argument it will be saved 
    set saved_pattern $pattern
    set pattern {}

    set elementTypes 0
    set attributeTypes 0
    foreach {var type comp} $choices {
	switch $type {
	    dir - dirs {
		set elementTypes 1
	    }
	    default {
		set attributeTypes 1
	    }
	}
	if { [ info commands generate_dtd_$type ] != "" } {
	    generate_dtd_$type $var $comp
	} else {
	    generate_dtd_default $var $comp
	}	
    }
    set choice_pattern $pattern
    set pattern $saved_pattern

    if { $elementTypes && $attributeTypes } {
	error "Incompatible types in choice"
    }    

    if $elementTypes {
	lappend pattern ([ join $choice_pattern " | " ])
    }

}

proc xml::generate_dtd_password {var comp} {
    upvar attributes attributes

    lappend attributes $var CDATA \#IMPLIED
    lappend attributes ct:$var CDATA \#IMPLIED
}

## Generates DTD for dir in a folder class
## that are mapped into an element
proc xml::generate_dtd_dir {var comp} {
    upvar processed_classes processed_classes
    upvar pending_classes pending_classes
    upvar pattern  pattern

    lappend pattern $comp			    
    if { [ lsearch $processed_classes $comp ] == -1 } {

	lappend pending_classes $comp
	lappend processed_classes $comp
    }
}

## Generates DTD for dirs in a folder class
## that are mapped into repeated elements
proc xml::generate_dtd_dirs {type comp} {
    upvar processed_classes processed_classes
    upvar pending_classes pending_classes
    upvar pattern pattern
    
    lappend pattern $comp*
    if { [ lsearch $processed_classes $comp ] == -1 } {

	lappend pending_classes $comp
	lappend processed_classes $comp
    }
}

## Generates DTD for menus in a folder class
proc xml::generate_dtd_menu {var comp} {
    upvar attributes attributes

    return [ generate_dtd_list $var $comp ]
}

## Generates DTD for list in a folder class
## that are mapped into attributes with enumeration
proc xml::generate_dtd_list {var comp} {
    upvar attributes attributes

    # 'join' doesn't work in multi words elements
    # set enum [ format {(%s)} [ join $comp { | } ] ]
    set enum ""
    set sep ""
    set valid 1
    foreach el $comp {
	if { [ llength $el ] > 1 } {
	    # enum elements must be XML's nmtokens 
	    # (cannot have spaces)
	    set valid 0
	}
	
	append enum $sep [ list $el ]
	set sep " | "
    }
    if $valid {
	set enum [ format {(%s)} $enum ]
	lappend attributes $var $enum \#IMPLIED 
    } else {
	lappend attributes $var CDATA \#IMPLIED
    }
}


## Generates DTD for all other types in a folder class
## that are mapped into attributes with CDATA
proc xml::generate_dtd_default {var comp} {
    upvar attributes attributes

    lappend attributes $var CDATA \#IMPLIED
}


## Convert XML data into a Mooshak structure
proc xml::unserialize {dir data} {

    strip_unused_xml data
    parse_text data text
    if { [ parse_tag data tag attrs ] } {
	if { [ is_empty_tag $attrs ] } {
	    set container {}
	} else {
	    parse_container $tag data container
	}
	set dir [ get_path $dir $dir $tag $attrs ]
	start_element $tag $attrs $dir
	parse_children $dir $dir container	
	end_element $tag $dir
    } else {
	error "invalid top element"
    }   
    parse_text data text
    if { $data != "" } {
	error "more than one top element"
    } 
}	

## Check if tags in text are closed balanced and with valid attributes
proc xml::check_embed_xml {data} {

    while 1 {
	parse_text data text
	if { [ parse_tag data tag attrs ] } {
	    check_attributes $attrs
	    if { ! [ is_empty_tag $attrs ] } {
		parse_container $tag data container
		check_embed_xml $container
	    }
	} else break
    }
}


proc xml::check_attributes {attrs} {

    set names {}
    set first 1

    while 1 {
	if { [ regexp {^(\s*)(\w[\w\d_:]*)\s*=\s*(\'|\")(.*)$} $attrs - \
		   sep name del attrs ] } {
	    if { [ lsearch $names $name ] > -1  } {
		error [ format "Duplicated attribute '%s'" $name ]
	    } else {
		lappend names $name
	    }

	    if $first {
		set first 0
	    } else {
		if { [ string equal $sep "" ] } {
		    error [format "No separators before attribute '%s'" $name]  
		}
	    }

	    if [ regexp [ format {^([^%s]*)%s(.*)$} $del $del ] \
		     $attrs - value attrs ] {
		continue
	    } else {
		error [ format "Invalid value of attribute '%s'" $name ]
	    }
	} else  break
    }

    string trim $attrs
    if { $attrs != "" && ! [ string equal $attrs "/" ] } {
	error [ format "invalid attribute starting with: '%s'" \
		    [ string range $attrs 0 5 ] ]
    }
}

## -------------------------------------------------------------
## all parsing commands (those starting with parse_):
##	receive a buffer (data) by reference
##	return a boolean (true if symbol was recognized)
##	consume recognized symbols from buffer
## -------------------------------------------------------------

   

## Parse children of an element (skipping text nodes)
## and copy its data to sub-folders
proc xml::parse_children {base_path current_path data_} {
    upvar $data_ data
    
    parse_text data text		;# skip text node
    while { [ parse_tag data tag attrs ] } {
	set path [ get_path $base_path $current_path  $tag $attrs ]
	start_element $tag $attrs $path

	if [ is_empty_tag $attrs ] {
	    parse_text data text	;# skip text node
	} else {
	    parse_container $tag data value
	    parse_text data text	;# skip text node
	    if [ is_not_pcdata $value ] {
		parse_children $base_path $path value
	    } else {		
		# Mooshak data doesn't have text elements
		set IGNORE [ unprotect_pcdata $value ]
	    }
	}
	end_element $tag $path
    }    
    parse_text data text		;# skip text node
}

## Process start of element tag (with attributes)
proc xml::start_element {type attrs path} {
    variable ::data::Attributes
    variable UNDEF

    # process element and bind it to a folder
    # create a new perobj, even it it exists
    set seg [ data::new $path $type ]   
    foreach  {var type comp}	$Attributes($type) {

	set value [ attribute_value $var $attrs ]

	switch $type {
	    password {
		# if no password has given and there is 
		# a clear text password then crypt it and use it
		if { $value == $UNDEF } {
		    set clear_text_password [ attribute_value ct:$var $attrs ]
		    if { $clear_text_password != "" } { 
			set value [ Session::crypt $clear_text_password ]
		    }
		}
	    }
	    dirs - dir { continue }
	}

	set ${seg}::${var} $value	
    }
}

## process end of element tag
proc xml::end_element {type path} {
    # save folder and wrap up
    #puts [ format {</ul></li>} ]

    data::write $path
	   
    #puts {</ul>}
}


## Return an attribute value from a string of attributes
## Attribute name and value must be separated by = (with optional white chars)
## Attribute values must be delimited by either " or ' and this chars
##  may occur in value if escaped as XML entities
proc xml::attribute_value {name attributes} {
    variable UNDEF

    if [ regexp [ format {(?:^|\s)%s\s*=\s*(\"|\')(.*)$} $name ] \
	     $attributes - sep rest ] {
	if [ regexp [ format {^(.*?)%s} $sep ] $rest - value ] {
	    regsub -all {&quot;} $value \" value
	    regsub -all {&apos;} $value \' value
	} else {
	    error "attributes construct error"
	}	    
    } else {
	set value $UNDEF
    }
    return $value

}


## Returns path  to persistent object for dir given type
proc xml::get_path {base_path current_path type arguments} {
    variable UNDEF

    set id [ attribute_value xml:id $arguments ]
    if [ string equal $id $UNDEF ] {
	if [ string equal [ data::class $current_path ] $type ] {
	    set path $current_path
	} else {
	    # generate a dirname
	    set prefix [ string tolower $type ]
	    set number 1
	    while { [ file exists [set path $current_path/$prefix$number] ] } {
		incr number
	    }
	}
	
    } else {	
	set path [ id2path $base_path $id  ]
    }
    return $path
}

## Is an empty tag?
proc xml::is_empty_tag {attributes} {
    return [ regexp {/$} $attributes ]
}

## Is XML PCDATA? (i.e. does not contain tags)
## TOO SIMPLISTIC COUDL BE A CDATA BLOCK !!
proc xml::is_not_pcdata {data} {
    return  [ regexp {<|>} $data ]
}

## Replace < and > by XML entities em PCDATA
proc xml::protect_pcdata {data} {
    regsub -all {<} $data {\&lt;} data
    regsub -all {>} $data {\&gt;} data
    regsub -all {\"} $data {\&quot;} data
    regsub -all {\'} $data {\&apos;} data
    return $data
}

## Replace XML entities by corresponding chars in PCDATA
proc xml::unprotect_pcdata {data} {
    regsub -all {\&lt;} $data {<} data
    regsub -all {\&gt;} $data {>} data
    regsub -all {\&quot;} $data \" data
    regsub -all {\&apos;} $data \' data
    return $data
}


## Convert file pathname into a valid XML id
proc xml::path2id {base path} {
    variable SAFE_ID_PREFIX
    
    set id $path
    regsub -all {\.} $id {_} id
    regsub -all {/} $id {.} id
    regsub -all {[^\w\d\.\-\_\:]} $id {_} id
    
    if { [ regexp {^[^\w\_\:]} $id ] } {
	set id ${SAFE_ID_PREFIX}$id
    }

    return $id
}

## Convert an XML id back into file pathname
proc xml::id2path {base id} {
    variable SAFE_ID_PREFIX

    if { ! [ regsub ^${SAFE_ID_PREFIX} $id {} path ] } {
	set path $id 
    }
    regsub -all {\.} $path {/} path

    return $base/$path
}


## Strip DTD, comments and processing instructions
proc xml::strip_unused_xml {data_} {
    upvar $data_ data

    return [ expr \
		 [ regsub {<!DOCTYPE\s+\w+\s+\[.*\]>} $data {} data ] || \
		 [ regsub -all {<\?xml.*?\?>} $data {} data ] || \
		 [ regsub -all {<!--.*?-->} $data {} data ] ]
}

## Set and consumes text in the beginning of data
proc xml::parse_text {data_ text_} {
    upvar $data_ data
    upvar $text_ text

    return [ regexp {^([^<]*)(<?.*)} $data - text data ]
}

## Set and consumes dtd in the beginning of data
## NOT TESTED !! 
proc xml::parse_dtd {data_ dtd_} {
    upvar $data_ data
    upvar $dtd_ dtd

    return [ regexp {^(<!DOCTYPE\s+\w+\s+\[.*\]>)(.*)} $data - dtd data ]
}


## Set and consumes tag (with its attrs) in the beginning of data 
proc xml::parse_tag {data_ tag_ attributes_} {
    upvar $data_ data
    upvar $tag_ tag
    upvar $attributes_ attributes

    return [ regexp  {^<(\w+)\s*(.*?)>(.*)} $data - tag attributes data ] 
}


## Set the container (up to the end tag) of given element.
## Assumes the start tag was already consumed
## (yes, it takes care of nested tags)
## Container and end tag are consumed
proc xml::parse_container {tag data_ container_} {
    upvar $data_ data
    upvar $container_ container

    set container ""
    set level 1

    # REGULAR EXPRESSIONS DON'T WORK FOR LARGE DATA BUFFERS 
    #while {[ regexp -nocase "^(.*?)<(/?)${tag}(.*)$" $data - pre end rest]} {}

    # set safe 2000	;# avoid too many top elements
    set start 0

    while { [ set pos [ string first $tag $data $start ] ] > -1 }  {
	# if { [ incr safe -1  ] <= 0 } break
	# is complete tag ?
	set length [ string length $tag ]
	set before [ string index $data [ expr $pos-1 ] ]
	set after  [ string index $data [ expr $pos + $length ] ]
	
	if { ! ( 
		[ string equal $before "/" ] || 
		[ string equal $before "<" ] 
		) ||
	     ! (
		[ string equal $after ">" ] ||
		[ string is space $after ] 
		)
	 } {
	    set start [ expr $pos + $length ]
	    continue
	    # not really a tag (not preceeded by either < or / 
	    #                   and not terminated by space)
	}

	# is end tag ?
	set end [ string equal [ string index $data [ expr $pos-1 ] ] / ]

	if $end {
	    set offset 3
	} else {
	    set offset 2
	}       

	set pre [ string range $data 0 [ expr $pos - $offset ] ]
	set rest [ string range $data [expr $pos + $length ] end]

	append container $pre

	# if [ regexp {^([^>]*>)(.*)$} $rest - pre data ] {}
	if { [ set pos [ string first > $rest ] ] > -1 } {
	
	    set args [ string range $rest 0 $pos ]
	    set data [ string range $rest [ expr $pos + 1 ] end ]
	    
	    if $end {
		incr level -1 
		if { $level == 0 } {
		    break
		} else {
		    append container </${tag}${args}
		}
	    } else {
		incr level
		append container <${tag}${args}
	    }
	}
    }
    if { $level == 0 } {
	return 1
    } else {
	error "Closing tag $tag not found"
    }
}



