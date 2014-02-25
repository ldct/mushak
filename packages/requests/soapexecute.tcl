#SOAPEXECUTE 

package provide soapexecute 0.1

package require ncgi
package require SOAP::CGI
package require SOAP::Utils
package require dom


namespace eval soapexecute {
    
    variable user
    variable token
    variable cmdname
    variable prog_name
    variable message
    variable prog
}
    
proc soapexecute::command_line {} {
    
    if {[catch { write [ send_mooshak ] } msg]} {
	
	set html "<!doctype HTML public \"-//W3O//DTD W3 HTML 2.0//EN\">\n"
	append html "<html>\n<head>\n<title>CGI Error</title>\n</head>\n<body>"
	append html "<h1>CGI Error</h1>\n<p>$msg</p>\n"
	append html "<br>\n<pre>$::errorInfo</pre>\n"
	append html "</body>\n</html>"
	write $html
    }       
}

proc soapexecute::write {html} {
    
    puts "Content-Type: text/html"
    set len [string length $html]
    puts "X-Content-Length: $len"
    incr len [regexp -all "\n" $html]
    puts "Content-Length: $len"
    
    puts "\n$html"
    catch {flush stdout}
}


proc soapexecute::send_mooshak {} {
    variable user
    variable token
    variable cmdname
    variable prog
    variable message
    variable prog_name
    
    get_values
    
    set doc_root [dom::DOMImplementation create]
    set el_env [ dom::document createElement $doc_root "MooshakReply" ]
    dom::element setAttribute $el_env "xmlns" "http://www.ncc.up.pt/mooshak"
    
    #user
    set el_user [ dom::document createElement $el_env "user" ]
    dom::element setAttribute $el_user "id" $user
    dom::element setAttribute $el_user "token" $token
    
    #ignorando para ja os parametros do comando
    set el_cmd [ dom::document createElement $el_env "command" ]
    dom::element setAttribute $el_cmd "name" $cmdname
    
    #message
    set el_msg [ dom::document createElement $el_env "message" ]
    dom::element setAttribute $el_msg "status" "Ok por agora"
    
    #table - ignorando field's etc...
    dom::document createElement $el_env "table" 
    
    # We have to strip out the DOCTYPE element though. It would be better to
    # remove the DOM element, but that didn't work.
    set prereq [dom::DOMImplementation serialize $doc_root]
    set req {}
    dom::DOMImplementation destroy $doc_root     ;# clean up
    regsub "<!DOCTYPE\[^>\]*>\n" $prereq {} req  ;# hack
    
    return $req       
}

proc soapexecute::get_values {} {
    
    variable user
    variable token
    variable cmdname
    variable prog
    variable message
    variable prog_name
    

    set xml [ ncgi::query ]
    
    set code [SOAP::CGI::do_encoding $xml]

    set doc_root [::dom::DOMImplementation parse $code ] 
    
    set val [::SOAP::Utils::selectNode $doc_root "/MooshakRequest/command"]
    set cmdname [dom::element getAttribute $val "name" ]
    
    set val [::SOAP::Utils::selectNode $doc_root "/MooshakRequest/user"]
    set user [dom::element getAttribute $val "name" ]
    set token [dom::element getAttribute $val "token" ]
    
    set val [::SOAP::Utils::selectNode $doc_root "/MooshakRequest/command/program"]
    set prog_name [ dom::element getAttribute $val "name" ]
}



