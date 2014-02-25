<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" version="4.01" encoding="ISO-8859-1"/>
  <xsl:strip-space elements="*" />

  

<xsl:template match="exam">
<!--
<!DOCTYPE html
	PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
-->
<html>
	<head>
        <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1"/>
        <meta http-equiv="Expires" content="0"/>
	<title>	Mooshak: exam </title>
	</head>
	<body>	
	      <xsl:apply-templates select="student"/>
	      <p/>
	      <xsl:apply-templates select="problem"/>

	</body>
</html>	
</xsl:template>


<!-- Student identification top panel					-->
<xsl:template match="student">

<table border="1" width="100%">
	<tr><th>Nome</th><td><xsl:value-of select="name"/></td></tr>
	<tr><th>ID</th><td><xsl:value-of select="id"/></td></tr>
</table>
</xsl:template>


<!-- Problem solving bottom panel 					-->
<xsl:template match="problem">
<table border="1" width="100%">
	<tr><th>Descrição</th><th>Resolução</th></tr>
	<tr>
		<td><xsl:value-of select="description"/></td>
		<td>
		<form>
		<textarea cols="80" rows="20">
		<xsl:value-of select="resolution"/>
		</textarea>
		</form>
		</td>
	</tr>
</table>
</xsl:template>



</xsl:transform>