<?xml version="1.0" encoding="ISO-8859-1"?>
<!--									-->
<!--	Formatting quizzes in Mooshak 			zp@ncc.up.pt	-->
<!--							2005		-->
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" version="4.01" encoding="ISO-8859-1"/>
  <xsl:strip-space elements="*" />

<xsl:param name="print" select="'no'"/>

<xsl:template match="/">
	Print: <xsl:value-of select="$print"/>
	
	<xsl:apply-templates select="quiz"/>

</xsl:template>


<xsl:template match="quiz">
	Print: <xsl:value-of select="$print"/>
	Yes confirmed
</xsl:template>

<!--
<xsl:template match="quiz[print = 'yes']">
	Print: <xsl:value-of select="$print"/>
	Yes confirmed
</xsl:template>

<xsl:template match="quiz[$print = 'no']">
	Print: <xsl:value-of select="$print"/>
	no confirmed
</xsl:template>
-->

</xsl:transform>