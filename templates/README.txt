
 -- Template directory

This directory contains HTML templates for page layout, grouped in
sub-directories according to the (natural) language in which they are
written. The names of these sub-directories must be 2 letter ISO codes
for the language in which files are written (ex "en" for English and
"pt" for Portuguese).

The main sub-directory is the one with layouts in English
("en"). Other directories contain translations of files in "en" to 
other languages.

Some templates are broken in parts using the pseudo-tag <!part>. This
pseudo tag requires an attribute "ext" to reference different
parts. These tags are processed by the "template" package in order to
use templates for pages where some parts can be repeated, omitted, or
interchanged.

For a simple example on the use of parts consider a request that
enumerates a list implemented with the procedures "enumerate" using
the template "enumerate.html". The header and footer on the page are
fixed but there is a part for each item that must be repeated
according to the number of item. Here is an example of the Tcl and 
HTML code:


--------------------------------------------------- Tcl code -------

	template::load enumerate.html

	template::write header
	foreach item $list {
		template::write line
	}
	template::write footer

--------------------------------------------------- HTML code ------

	<!part ext="header">	
		<UL>
	<!/part ext="header">	

	<!part ext="line">
			<LI> $item </LI>
	<!/part ext="line">	

	<!part ext="footer">
		</UL>
	<!/part ext="footer">
		

-----------------------------------------------------------------------