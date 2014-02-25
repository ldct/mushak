SCRIPTS=classes/*.tcl requests/*.tcl perobjs/*.tcl utils/*.tcl net/*.tcl

TCL=tclsh

all: tclIndex pkgIndex.tcl

tclIndex: ${SCRIPTS}
	echo "auto_mkindex . ${SCRIPTS}" | ${TCL}

pkgIndex.tcl: ${SCRIPTS}
	echo "pkg_mkIndex -verbose -direct . ${SCRIPTS}" | ${TCL}

clean: 
	rm -f tclIndex pkgIndex.tcl
