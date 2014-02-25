#
# Mooshak: managing programming contests on the web		April 2001
# 
#			Zé Paulo Leal 		
#			zp@dcc.fc.up.pt
#
#-----------------------------------------------------------------------------
# file: data4mining.tcl
# 
## extraction of data for mining

package provide data4mining 1.0

package require file


namespace eval data4mining {

    variable KEYWORDS
    array set KEYWORDS {
	C	{
	    auto	    break	    case	    char
	    const	    continue	    default	    do
	    double	    else	    enum	    extern
	    float	    for		    goto	    if
	    int		    long	    register	    return
	    short	    signed	    sizeof	    static
	    struct	    switch	    typedef	    union
	    unsigned	    void	    volatile	    while 
	}
	CPP {
	    auto	    break	    case	    char
	    const	    continue	    default	    do
	    double	    else	    enum	    extern
	    float	    for		    goto	    if
	    int		    long	    register	    return
	    short	    signed	    sizeof	    static
	    struct	    switch	    typedef	    union
	    unsigned	    void	    volatile	    while 
	    
	    asm         dynamic_cast  namespace  reinterpret_cast  try
	    bool        explicit      new        static_cast       typeid
	    catch       false         operator   template          typename
	    class       friend        private    this              using
	    const_cast  inline        public     throw             virtual
	    delete      mutable       protected  true              wchar_t

	    and      bitand   compl   not_eq   or_eq   xor_eq
	    and_eq   bitor    not     or       xor
	    
	}
	JAVA {
	    abstract	continue 	for 		new 	    switch
	    assert 	default 	goto 		package 	
	    synchronized
	    boolean 	do 		if 		private 	this
	    break 	double 		implements 	protected 	throw
	    byte 	else 		import 		public 		throws
	    case 	enum 		instanceof 	return 		
	    transient
	    catch 	extends 	int 		short 		try
	    char 	final 		interface 	static 		void
	    class 	finally 	long 		strictfp 	
	    volatile
	    const 	float 		native 		super 	while
	}
	PERL {
	    not exp log srand xor s qq qx xor
	    s x x length uc ord and print chr
	    ord for qw q join use sub tied qx
	    xor eval xor print qq q q xor int
	    eval lc q m cos and print chr ord
	    for qw y abs ne open tied hex exp
	    ref y m xor scalar srand print qq
	    q q xor int eval lc qq y sqrt cos
	    and print chr ord for qw x printf
	    each return local x y or print qq
	    s s and eval q s undef or oct xor
	    time xor ref print chr int ord lc
	    foreach qw y hex alarm chdir kill
	    exec return y s gt sin sort split
	    
	    dispose  exit  false  new  true
	}

	PASCAL {
	    absolute  	    and  array  asm  begin  
	    case     const  constructor  destructor  div  do  downto  
	    else  end  file  for  function  goto  if  implementation  
	    in  inherited  inline  interface  label  mod  nil  not  
	    object  of  on  operator  or  packed  procedure  program  
	    record  reintroduce  repeat  self  set  shl  shr  string  
	    then  to  type  unit  until  uses  var  while  with  xor
	}

	PYTHON {
	    and	 assert	 break	 class	 continue
	    def	 del	 elif	 else	 except
	    exec	 finally	 for	 from	 global
	    if	 import	 in	 is	 lambda
	    not	 or	 pass	 print	 raise
	    return	 try	 while	
	}

	TCL {
	    after append array auto_execok auto_import auto_load 
	    auto_load_index auto_qualify binary bgerror break catch
	    cd clock close concat continue dde default else elseif
	    encoding eof error eval exec exit expr fblocked fconfigure
	    fcopy file fileevent flush for foreach format gets glob global
	    history if incr info interp join lappend lindex linsert list 
	    llength load lrange lreplace lsearch lsort namespace open package
	    pid pkg_mkIndex proc puts pwd read regexp regsub rename resource
	    return scan seek set socket source split string subst switch 
	    tclLog tell time trace unknown unset update uplevel upvar 
	    variable vwait while 	    
	}  
	VB {
	    AddHandler AddressOf Alias And AndAlso As Boolean ByRef Byte 
	    ByVal Call Case Catch CBool CByte CChar CDate CDec CDbl Char
	    CInt Class CLng CObj Const Continue CSByte CShort CSng CStr
	    CType CUInt CULng CUShort Date Decimal Declare Default 
	    Delegate Dim DirectCast Do Double Each Else ElseIf End EndIf
	    Enum Erase Error Event Exit False Finally For Friend Function
	    Get GetType Global GoSub GoTo Handles If Implements Imports In
	    Inherits Integer Interface Is IsNot Let Lib Like Long Loop Me
	    Mod Module MustInherit MustOverride MyBase MyClass Namespace
	    Narrowing New Next Not Nothing NotInheritable NotOverridable
	    Object Of On Operator Option Optional Or OrElse Overloads
	    Overridable Overrides ParamArray Partial Private Property
	    Protected Public RaiseEvent ReadOnly ReDim REM RemoveHandler
	    Resume Return SByte Select Set Shadows Shared Short Single
	    Static Step Stop String Structure Sub SyncLock Then Throw To
	    True Try TryCast TypeOf Variant Wend UInteger ULong UShort
	    Using When While Widening With WithEvents WriteOnly Xor
	    #Const #Else #ElseIf #End #If
	}

    }
}

## Extract data from submissions in this directory and put them in channel
proc data4mining::extract {submissions } {
    variable previous_program_file

    array set previous_program_file {}

    set contest [ file tail [ file dirname $submissions ] ]

    foreach sub [ glob -type d -nocomplain $submissions/* ] {

	if { [ catch { 
	    set sb [ data::open $sub ]
    
	    set line {}

	    append_global_fields  line $contest

	    append_basic_fields   line $sb 

	    append_program_fields line $sb $sub $submissions

	    puts [ join $line \t ]
	    flush stdout

	} message ] } {
	    puts  $message
	    continue
	}
    }
}

## plain um line header with all the field names in order
proc data4mining::print_header {} {

    set fields { 
	Host Contest Team Problem Language 
	Date Time State Classify Mark Size
	Program_Words Program_Unique_Words 
	Program_Reserved Program_Unique_Reserved
	Solution_Words Solution_Unique_Words 
	Solution_Reserved Solution_Unique_Reserved
	Diff_Blocks Diff_Lines
    }

    puts [ join $fields \t ]
 
}

## append to line basic fields from submission
proc data4mining::append_global_fields {line_ contest} {
    global URL_BASE
    upvar $line_ line 

    lappend line $URL_BASE
    lappend line $contest
}

## append to line basic fields from submission
proc data4mining::append_basic_fields {line_ sb} {
    upvar $line_ line 

    lappend line [ set ${sb}::Team    	]
    lappend line [ set ${sb}::Problem 	]
    lappend line [ set ${sb}::Language	]
    
    lappend line [ set ${sb}::Date	]
    lappend line [ set ${sb}::Time	]
    lappend line [ set ${sb}::State	]
    lappend line [ set ${sb}::Classify	]
    lappend line [ set ${sb}::Mark	]
    lappend line [ set ${sb}::Size	]
}


## append to line basic fields from submission
proc data4mining::append_program_fields {line_ sb sub submissions} {
    upvar $line_ line 
    variable previous_program_file

    set team		[ set ${sb}::Team ]
    set problem		[ set ${sb}::Problem ]
    set program		[ set ${sb}::Program ]

    set program_file $sub/$program
    
    program_words $program_file program_count
    
    lappend line $program_count(all_words)
    lappend line $program_count(unique_words)
    lappend line $program_count(reserved)
    lappend line $program_count(unique_reserved)
    
    solution_words $submissions $problem solution_count

    lappend line $solution_count(all_words)
    lappend line $solution_count(unique_words)
    lappend line $solution_count(reserved)
    lappend line $solution_count(unique_reserved)    

    if { [ info exists \
	       previous_program_file($team,$problem) ] } {
	
	diff $program_file \
	    $previous_program_file($team,$problem) \
	    diff_blocks \
	    diff_lines
    } else {
	set diff_blocks {}
	set diff_lines  {}
    }
    
    lappend line $diff_blocks
    lappend line $diff_lines
    
    set previous_program_file($team,$problem) $program_file
}



# number of blocks and lines that changed 
proc data4mining::diff {actual previous diff_blocks_ diff_lines_} {
    upvar $diff_blocks_ diff_blocks 
    upvar $diff_lines_  diff_lines

    catch { exec diff $actual $previous  } out

    set diff_blocks [ llength [ regexp -all -inline {\n---\n} $out ] ]

    set diff_lines [ llength [ regexp -all -inline {\n<|>} $out ] ]

}

proc data4mining::solution_words {submissions problem count_} {
    upvar $count_ count
    variable cache_solution_words

    if { [ info exists cache_solution_words($problem) ] } {

	array set count $cache_solution_words($problem)

    } else {

	set problem_dir [ glob $submissions/../problems/$problem ]
	set pd [ data::open  $problem_dir ]
	set solution_file $problem_dir/[ set ${pd}::Program ] 
	if { [ file exists $solution_file ] } {
	    program_words $solution_file count

	} else {
	    array set count { 
		all_words {} unique_words {} reserved {} unique_reserved {}
	    }
	}

	set cache_solution_words($problem) [ array get count ]
    }
}


# compute word counts from program file
proc data4mining::program_words {program_file count_} {
    upvar $count_ count

    set program_text [ file::read_in $program_file ]

    set languages_path [ file normalize $program_file/../../../languages ]

    data::open $languages_path

    set language_path [ $languages_path search $program_file ]
    set language [ file tail $language_path ]

    set clean_program_text 	[ data4mining::cleanup $program_text ]

    set all_words 		[ words $clean_program_text ]
 
    set count(all_words)	[ llength $all_words ]
    set count(unique_words)	[ llength [ unique $all_words ] ]
 

    if { [ catch { set reserved	[ reserved $language $all_words ] } ] } {
	set count(reserved)		{}
	set count(unique_reserved)	{}
    } else {
	set count(reserved)		[ llength $reserved ]
	set count(unique_reserved)	[ llength [ unique $reserved ] ]

    }
}


# remove comments and qualified string/char literals 
proc data4mining::cleanup {text} {

    regsub -all {/\*.*?\*/} $text {} text
    regsub -all {//.*?\n} $text {} text

    regsub -all {\".*?\"} $text {} text
    regsub -all {\'.*?\'} $text {} text

    return $text
}


# return words from text (program)
proc data4mining::words {text} {

    return [ regexp -all -inline {[a-zA-Z_]\w*} $text ]
}

## return unique words from list of words
proc data4mining::unique {words} {

    set unique {}
    foreach word $words {
	if { [ lsearch $unique $word ] == -1 } {
	    lappend unique $word
	}
    }
    return $unique
}

## reserved words from 
proc data4mining::reserved {language words} {
    variable KEYWORDS

    set lang [ string toupper $language ]
    if [ info exists KEYWORDS($lang) ] {
	return [ regexp -all -inline [ join $KEYWORDS($lang) | ] $words ]
    } else {
	error "invalid language '$language'"
	return {}
    }
}