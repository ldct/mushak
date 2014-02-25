#
# Generated automatically from pkgIndex.tcl.in by configure.
#

# There is some uncertainty over what this package should be called -- 
# tcldom, dom, or dom::c -- so for now provide all three.
#
package ifneeded tcldom 2.0 \
    [list load [file join $dir tcldom2.0.so]]

package ifneeded dom 2.0 \
    "load [file join $dir tcldom2.0.so] Tcldom ;
     package provide dom 2.0"

package ifneeded dom::c 2.0 \
    "load [file join $dir tcldom2.0.so] Tcldom ;
     package provide dom::c 2.0"

#*EOF*
