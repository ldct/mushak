#!/usr/bin/tclsh


set PROXY http://localhost/~mooshak


cd [ file dirname [ pwd ]/[ info script ] ]

lappend auto_path ../../lib/tclsoap1.6.7 
lappend auto_path ../../lib/tcldom2.0

package require SOAP
package require SOAP::Utils
package require dom
package require SOAP::CGI

#SOAP object, Wrapper and Parser ##########################################


#Wrapper
#supondo nesta fase que a unica variavel opcional e o optfile
proc build_request {procVarName command atrs optfile } {
    
    #construir haeaders -> funcao env_head
    set doc_root [dom::DOMImplementation create]
    set el_env [dom::document createElement $doc_root "MooshakRequest"]
    dom::element setAttribute $el_env "xmlns" "http://www.ncc.up.pt/mooshak"
    
    #contruir body -> funcao env_body ( args )
    
    #user
    set el_user [ dom::document createElement $el_env "user" ]
    dom::element setAttribute $el_user "id" "bitoiu"
    dom::element setAttribute $el_user "token" "token64"
    
    #command
    set el_cmd [ dom::document createElement $el_env "command" ]
    dom::element setAttribute $el_cmd "name" $command
    
    #command -> atrbs
    foreach {nome valor} $atrs {
	dom::element setAttribute [ dom::document createElement $el_cmd $nome ] "valor" $valor
    }
    
    #command -> program
    if { [string length $optfile] > 0 } {     
	
	set el_prog [ dom::document createElement $el_cmd "program" ]
	dom::element setAttribute $el_prog "name" $optfile
	set fd   [ open $optfile RDONLY ]
	set full [ read $fd ]
	close $fd
	
	#command -> program -> CDATA
	set el_data [ dom::document createCDATASection $el_prog $full]		      
    }
    
    #puts stderr [dom::DOMImplementation serialize $doc_root ]

    # We have to strip out the DOCTYPE element though. It would be better to
    # remove the DOM element, but that didn't work.
    set prereq [dom::DOMImplementation serialize $doc_root]
    set req {}
    dom::DOMImplementation destroy $doc_root     ;# clean up
    regsub "<!DOCTYPE\[^>\]*>\n" $prereq {} req  ;# hack

    return $req
 
}

#Parser
proc reply_parse {proc xml} {
    
    puts stderr $xml
}



#Object
SOAP::create send_mooshak                               \
    -uri http://www.ncc.up.pt/mooshak                   \
    -proxy $PROXY				 	\
    -wrapProc build_request                             \
    -parseProc reply_parse                              \
    -params { comando string atribs list file_send string }

######################################################################################

puts [ send_mooshak submit {argx numero1 argy numero2 argz numero3} test.c ]

puts [SOAP::dump -request send_mooshak]
