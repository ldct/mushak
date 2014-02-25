<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" version="4.01" encoding="ISO-8859-1"/>
  <xsl:strip-space elements="*" />

  

<xsl:template match="error">

<html>
	<head>
        <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1"/>
        <meta http-equiv="Expires" content="0"/>
	<title>	Mooshak: ERROR </title>
	</head>
	<body>	
		<html>
<head>
<title>Mooshak: Error: <xsl:value-of select="//message"/></title>
   <link 
	rel	="stylesheet" 
	href	="../styles/base.css" 
	type	="text/css"/>
</head>
<body>

	<h1>Mooshak ERROR</h1>
	<h2><xsl:value-of select="//message"/></h2>
	<script>
		alert('<xsl:value-of select="//message"/>');
	</script>
	<pre>
	<xsl:value-of select="//info"/>
	</pre>
</body>
</html>


	</body>
</html>


</xsl:template>

</xsl:transform>