#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: doc.tcl
# 
## Generation of XML documents

namespace eval doc {

    variable Current_document 0	;## document counter
    variable Current_node     0	;## node counter

    variable Top		;## array of top nodes indexed by document
    variable Preamble		;## list of nodes indexed by document
    
    variable Type		;## array of elements indexed by nodes
    variable Attributes		;## array of attributes indexed by nodes
    variable Children		;## array of attributes indexed by nodes

    variable TabSkip	     5	;## tab skip (in chars) used in XML ouput
    variable Version       1.0	;## XML version 
    variable Encoding    utf-8	;## default character encoding

    global ENCODING
    if [ info exists ENCODING ] {
	# set default encoding, if defined
	set Encoding $ENCODING
    }
}

# create a new document top node
proc doc::document { {preamble {}} {top {}} } {
    variable Current_document
    variable Preamble
    variable Version
    variable Encoding

    incr Current_document
    add_preamble $Current_document \
	[ processing_instruction xml [ format {version "%s" encoding "%s" } $Version $Encoding ] ]
    foreach node $preamble {
	add_preamble $Current_document $node
    }

    set_top $Current_document $top
    return $Current_document
    
}

## Set top node of a given document
proc doc::set_top {doc node} {
    variable Top

    set Top($doc) $node
}

## Add a (porcessing instruction) node as preamble of document
## Adding DTDs to preamble is not (yet?) supported
proc doc::add_preamble {doc node} {
    variable Type
    variable Preamble

    switch $Type($node) {
	processing-instruction {
	    lappend Preamble($doc) $node
	}
	default {
	    error "Cannot add to preamble a $Type($node)"
	}
    }
}

## Generic procedure to create a node (attributes are not seen as nodes)
## $type is one of { element text procssing-instruction comment }
## $tag is also used for string in text and comment nodes
## $attributes is an even list of name followed by its value
## $children is a list of nodes of any type
proc doc::node {type tag {attributes {}} {children {}}} {
    variable Current_node
    variable Type
    variable Tag
    variable Attributes
    variable Children

    incr Current_node
    set Type($Current_node) $type
    set Tag($Current_node) $tag    
    
    switch $Type($Current_node) {
	element - processing-instruction {
	    if { [ llength $attributes ] % 2 == 0 } {
		set Attributes($Current_node) $attributes
	    } else {
		error "Odd number of elements in attribute list"
	    }
	}
	default {
	    if { $attributes != {} } {		
		error "Cannot set attributes in a node of type $Type($Current_node)"
	    }
	}
    }


    
    switch $Type($Current_node) {
	element {
	    set Children($Current_node) $children
	}
	default {
	    if { $children != {} } {
		error "Cannot set children to a node of type $Type($Current_node)"
	    }
	}
    }

    return $Current_node
}

## Add an attribute pair to an element or processing-instruction
proc doc::add_attribute {node name value} {
    variable Type
    variable Attributes

    switch $Type($node) {
	element - processing-instruction {
	    lappend Attributes($node) $name $value
	}
	default {
	    error "Cannot add attributes to a node of type $Type($node)"
	}
    }
}

## Add a child node to an element
proc doc::add_child {node child } {
    variable Type
    variable Children

    switch $Type($node) {
	
	element {
	    lappend Children($node) $child
	}
	default {
	    error "Cannot add children to a node of type $Type($node)"
	}		
    }
}

## Basic convenience procedures

proc doc::element {tag {attributes {}} {children {}}} { 
    return [ node  element $tag $attributes $children ]
}
proc doc::text {text} { 
    return [ node text $text ] 
}
proc doc::comment {comment} { 
    return [ node  comment $comment  ]
}
proc doc::processing_instruction {tag {attributes {}}} { 
    return [ node  processing-instruction $tag $attributes ]
}

## more convenience procedures

## Declare a XSL stylesheet 
proc doc::xsl-stylesheet {href} {
    return [ doc::processing_instruction xml-stylesheet \
		 [ list type "text/xsl" href $href ] ]
}	

## Create an element with a single text node as child 
## (such as anchors or headings in HTML)
proc doc::element_text {tag text {attributes {}}} { 
    return [ element $tag $attributes [ text $text ] ]
}

## Serialize a data structure in XML
proc doc::serialize {doc {pretty_print 1}} {
    variable Preamble
    variable Top
    
    set serial ""
    foreach node $Preamble($doc) {
	append serial [ serialize_node $node $pretty_print 0 ]
    }

    if { $Top($doc) == {} } {
	error "No top node"
    } else {
	append serial [ serialize_node $Top($doc) $pretty_print 0 ]
    }
    
}

## Serialize nodes recursively in XML
proc doc::serialize_node {node pretty_print level} {
    variable Type
    variable Tag
    variable Attributes
    variable Children

    set next_level [ expr $level + 1 ]
    if $pretty_print {
	variable TabSkip

	set tab [ expr $level * $TabSkip ]
	set serial [ format "%*s" $tab {} ]
    } else {
	set serial ""
    }
    switch $Type($node) {
	text	{ 	
	    append serial $Tag($node)	
	}
	comment { 
	    append serial [ format "<!--%s-->" $Tag($node) ] 
	}
	processing-instruction { 
	    set tag [ init_tag $Tag($node) $Attributes($node) ]
	    append serial [ format "<?%s?>" $tag]
	}
	element	{
	    set tag [ init_tag $Tag($node) $Attributes($node) ]
	    if { $Children($node) == {} } {
		append serial [ format "<%s/>" $tag ]
	    } elseif { 
		      $pretty_print && 
		      [ llength $Children($node) ] == 1 &&
		      [ string equal $Type($Children($node)) text ]
		  } {
		# special case of element with just one text element
		set text [ serialize_node $Children($node) 0 0 ] 
		append serial [ format "<%s>%s</%s>" $tag $text $Tag($node) ]

	    } else {
		append serial [ format "<%s>" $tag ]
		if $pretty_print { append serial "\n" }
		foreach child $Children($node) {
		    append serial [ serialize_node $child $pretty_print $next_level]
		}
		if $pretty_print { 
		    append serial [ format "%*s" $tab {} ]
		}
		append serial [ format "</%s>" $Tag($node) ]
	    }
	}
    }
    if $pretty_print { append serial "\n" }
    return $serial
}

## create the initial tag content (with attributes) 
## of an element or processing instruction node
proc doc::init_tag {name attributes} {

    set tag "$name"
    if { $attributes != {} } {
	foreach {name value} $attributes {
	    append tag [ format { %s="%s"} $name $value ]
	}
    }

    return $tag
}

proc doc::test {} {
    
    set doc [ document ]
    add_preamble $doc [ processing_instruction xml-stylesheet \
			    {type="text/xsl" href="../styles/quiz.xsl"} ]   
    set html [ element HTML ] 
    set_top $doc $html
    add_child $html [ comment "another test case" ] 
    add_child $html [ set head [ element HEAD ] ]
    add_child $head [ element_text TITLE "teste" ]
    add_child $html [ set body [ element BODY ] ]
    add_child $body [ element_text A "Zé Paulo" {HREF "http://www.ncc.up.pt/~zp"} ]

    serialize $doc
}



proc doc::test2 { {pretty_print 1} } {

    serialize [ document \
		    [ processing_instruction xml-stylesheet \
			  {type "text/xsl" href "../styles/quiz.xsl"} ] \
		    [ element HTML {} \
			  [ list \
				[ comment "another test case" ] \
				[ element HEAD {} \
				      [ element_text TITLE "teste" ] ]\
				[ element BODY {} \
				      [ list \
					    [ element_text H1 "Título" ] \
					    [ text "Esta é a página do " ] \
					    [ element_text A "Zé Paulo" \
						  {HREF "http://www.ncc.up.pt/~zp"} ] \
					    [ text "aqui vai uma lista" ] \
					    [ element OL {} \
						  [ list \
							[ element_text LI "primeiro" ] \
							[ element_text LI "segundo" ] \
							[ element_text LI "terceiro" ] ] ] ] ] ] ] ] $pretty_print
	       
}
