<?xml version="1.0" encoding="utf-8"?>
<!--									-->
<!--	Formatting service reports in Mooshak		zp@ncc.up.pt	-->
<!--							2011		-->
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" version="4.01" encoding="utf-8"
		doctype-public= "-//W3C//DTD HTML 4.01 Transitional//EN"
		doctype-system="http://www.w3.org/TR/html4/loose.dtd"
		indent="yes"
  />
  <xsl:strip-space elements="*" />



<xsl:template match="/">
<html>
	<head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <meta http-equiv="Expires" content="0"/>
	<title>	Mooshak Report </title>
	<link rel="stylesheet" href="../../styles/base.css" type="text/css"/>

	</head>
	<body>	

	  <xsl:apply-templates/>

	</body>
</html>	
</xsl:template>


<xsl:template match="report">
	  <h2>Report</h2>

	  Exercise: <xsl:value-of select="exercise"/>
	  
	  <xsl:apply-templates/>

</xsl:template>


<xsl:template match="tests">
  <table frame="box" rules="all">
    <tr>
      <th>	</th>
    </tr>
    <xsl:apply-templates/>
  </table>
</xsl:template>

<xsl:template match="test">
  <tr>
    <td><a href="{input}"><xsl:value-of select="input"/></a></td>
    <td><xsl:value-of select="expectedOutput"/></td>
    <td><xsl:value-of select="obtainedOutput"/></td>
    <td><xsl:value-of select="outputDifferences"/></td>
  </tr>
</xsl:template>



</xsl:transform>
