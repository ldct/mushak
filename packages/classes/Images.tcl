#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@ncc.up.pt
#
#-----------------------------------------------------------------------------
# file: Images.tcl
# 
## Images on the HTML problem description

package provide Images 1.0

package require data

Attributes Images {
    Fatal	fatal	{}
    Warning	warning {}        

    Image	fx	{}    
}

Operation Images::check {} {
}

Operation Images::_update_ {} {
    check::reset Fatal Warning

    return [ check::requires_propagation $Fatal ]
}


Operation Images::upload:from_archive ? {

    set dir ${_Self_}

    template::load 
    template::write    
}

Operation Images::uploading_from_archive args {
    variable ::Session::Conf
    variable ::file::TMP

    set dir ${_Self_} 
    set archive $TMP/$cgi::Field(file)

    set command [ file::unarchive_command $archive  0 ]
    process::exec_in_dir "$command $archive" $dir	    

    layout::window_open $Conf(controller)?data+$dir select
    layout::window_close
}
