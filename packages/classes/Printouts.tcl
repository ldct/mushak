#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Printouts.tcl
# 
## Managing printouts requested by teams during a contest


package provide Printouts 1.0

package require Printout

namespace eval Printouts {

    variable Tip	;# Tips on fields content and commands
    variable Help	;# Help on fields content

    array set Tip {
	Active		"Accept jobs for printing in the teams interface"
	Printer		"Printer queue name (empty for default printer)"
	Template	"HTML file with printout template"
	Config		"CSS file for configuring HTML template"
	List-Pending	"Include printouts in Pending listing"
    }

}

#------------------------------------------------------------------------------
#     Class definition


Attributes Printouts {
    Active		menu	{yes no}
    Printer		text	{}
    Template		fx	{.html}
    Config		fx	{.css}
    List-Pending	menu 	{yes no}
    Printout		dirs	Printout
}

Operation Printouts::_update_ {} {

    if { ! [ ${_Self_} active ] } { return 0 }

    if { ! [ file readable ${_Self_}/$Template ] } {
	${_Self_} make_template
    }

    if { ! [ file readable ${_Self_}/$Config ] } {
	${_Self_} make_config
    }

    if { $Printer == "" } {	
	# set Printer [ print::default_printer ]
	#
	# Empty printer queue will use the server's default printer
	# This is useful if configurartion are replicated for 
    }
    
    return 0
}

## Is printing active (teams cam print files)?  Defaults to no
Operation Printouts::active {} {
    if [ string equal $Active yes ] {
	return 1
    } else {
	return 0
    }
}

## Print a test page 
Operation Printouts::test_page ! {

    set printout ${_Self_}/teste
    data::new $printout Printout
    $printout create_test_page
    data::record $printout 
    if { [ set msg [ $printout do_print ] ] != ""  } {
	layout::alert $msg
    }
    file delete -force $printout

    content::show ${_Self_}
}

## Sets default printer
Operation Printouts::defaults:printer ! {
    set Printer [ print::default_printer ]
    data::record ${_Self_}
    content::show ${_Self_}
}

## Creates a default HTML template to format printouts
Operation Printouts::defaults:template ! {
    ${_Self_} make_template

    content::show ${_Self_} 1
}

Operation Printouts::make_template {} {
    variable ::Printout::AvailableVars

    set fd [ open ${_Self_}/$Template w ] 
    puts $fd {<table width="100%" border="1" cellspacing="10" cellpading="10">}
    foreach var $AvailableVars {
	puts $fd [ format {<tr><th valign="right">%s</th><td>$%s</td></tr>} \
		   [ translate::sentence $var ] $var ]
    }
    puts $fd {</table>}
    puts $fd {<!--NewPage-->}
    puts $fd {<pre>}
    puts $fd {$Content}
    puts $fd {</pre>}
    close $fd     

    layout::alert "Default template created"
}

# Crates a default CSS config file  for HTML to PS conversion
Operation Printouts::defaults:config ! {

    ${_Self_} make_config

    content::show ${_Self_} 1
}

# Crates a default CSS config file  for HTML to PS conversion
Operation Printouts::make_config {} {

    set fd [ open ${_Self_}/$Config w ] 
    puts $fd {
	@html2ps {
	    
	    paper {
		type: a4;
	    }       
	}
	/* use CSS2 blocks to configure HTML elements */	
	@page {
	    margin {
		left:   2.0cm;
		right:  2.0cm;
		top:    2.0cm;
		bottom: 2.0cm;
	    }
	}    

	BODY {
	    font-size:	24pt;
	}
	TD TH {
	    font-size:	24pt;
	}
    }
    close $fd     
    
    layout::alert "Default config created"
}

## Cheks if directory is ready for a contest (i.e. empty)
Operation Printouts::check {} {
    check::dir_start 0
    check::dir_empty
    check::dir_end 0

}

# cleans the directory (removes all printouts)
Operation Printouts::prepare {} {

    check::clear 
} 

## Printout listing
Operation Printouts::printouts {{profile admin}} {
    set message ""

    listing::header message

    set fields  [ listing::define_vars ]
    set update  [ expr $time * 60 ]
    set problem [ cgi::field problem "" ]
    set team	[ contest::team ]

    set list [ listing::restrict ${_Self_} ] 
    set list [ lsort -command 						  \
		   [ list listing::cmp [ list _${problem}_ _${team}\$ ] ] \
		   $list ]
    set all_subs [ lsort -decreasing [ listing::unrestrict ${_Self_} ] ]
    set n_subs   [ llength $all_subs ]

    set contest [ contest::active_path ]
    data::open $contest

    if { [ set limit [ $contest hide_listings message ] ] > -1 } {

	set list [ listing::older_submissions $list $limit ]
    }
    
    listing::part list pages last n
    
    foreach sub $list {
	if [ catch {
	    set m [ expr $n_subs - [ lsearch $all_subs $sub ] ]
	    data::open $sub
	    $sub listing_line $m $n $profile
	} msg ] {
	    #puts <pre>$msg</pre> ;# debug
	    incr n
	    # DONT SHOW CORRUPTED LINES
	    #set m $n
	    #layout::toggle_color m color
	    #template::write empty
	}
	incr n -1
    }

    listing::footer [ incr n ] $pages $list 
}
