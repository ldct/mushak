<?xml version="1.0" encoding="utf-8"?>
<!--									-->
<!--	Formatting quizzes in Mooshak 			zp@ncc.up.pt	-->
<!--							2005		-->
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" version="4.01" encoding="utf-8"
		doctype-public= "-//W3C//DTD HTML 4.01 Transitional//EN"
		doctype-system="http://www.w3.org/TR/html4/loose.dtd"
		indent="yes"
  />
  <xsl:strip-space elements="*" />

<xsl:param name="print" select="'no'"/>

<xsl:template match="/">
<html>
	<head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <meta http-equiv="Expires" content="0"/>
	<title>	Mooshak Quiz </title>
	<link rel="stylesheet" href="../../styles/base.css" type="text/css"/>

	<script language="JavaScript" src="../../styles/timer.js"></script>
	<script language="JavaScript" src="../../styles/quiz.js"></script>

<!--
http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML
-->

	<script type="text/javascript" src="../mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
	</script>

	<style>	
	body { padding: 10pt; }
	div.header {
		width: 		95%; 
	/* height: 	110px; */
		border: 	1pt; 
		border-style: 	solid; 
		padding:	10pt;
	}
	div.command {
		text-align: 	right;
		width: 		85%; 
		padding: 	2mm;
	}
	.message {
		white-space:	pre;
	}
	form {
		margin:		2mm;
	}

	.right {
		width: 1cm;
		color: green;
		padding: 3mm;
	}
	.right:before {
		content: "C";
	}
	.wrong {
		width: 1cm;
		color: red; 
		padding: 3mm;
	}
	.wrong:before {
		content: "E";
	}

	</style>
	</head>
	<body>	

	<xsl:choose>
		<xsl:when test="$print = 'yes'">
		  	<xsl:apply-templates select="quiz" mode="print"/>
		</xsl:when>
		<xsl:otherwise>
		  	<xsl:apply-templates select="quiz" mode="screen"/>
		</xsl:otherwise>
	</xsl:choose>

	</body>
</html>	
</xsl:template>


<xsl:template match="quiz[//type='empty']" mode="screen">
      	      <form name="quiz" method="post" action="."
	      	onSubmit="return checkOut();">

	      <xsl:apply-templates select="header"/>
	      <div class="command">
		      <input type="submit" value="Submeter"/>
		      <input type="hidden" name="Problem" value="A"/>
		      <input type="hidden" name="command" value="grade"/>
	      </div>
	      <div style="overflow: scroll; width: 95%; height: 35em;">
	      <xsl:apply-templates select="quizGroup"/>
	      </div>

	      </form>
	      <script language="JavaScript">
	      setAction("quiz")
	      </script>
</xsl:template>


<xsl:template match="quiz[//type='answered']"  mode="screen">
      	      <form name="logout" method="post" action=".">

	      <xsl:apply-templates select="header"/>
	      <div class="command">
		      <input type="submit" value="Sair"/>
		      <input type="hidden" name="command" value="logout"/>
	      </div>
	      <xsl:apply-templates select="quizGroup"/>

	      <script language="JavaScript">
	      setAction("logout")
	      </script>
	      </form>	
</xsl:template>


<xsl:template match="quiz[//type='answered']" mode="print">
	      <xsl:apply-templates select="header"/>

	      <xsl:apply-templates select="quizGroup"/>
</xsl:template>


<xsl:template match="header">
	      <div class="header">
		<table width="100%">
		  <tr>
		    <td> 
		      <strong>Exame: </strong>
		      <xsl:value-of select="designation"/><br/>
		    </td>
		    <td>
		      <strong>Aluno: </strong> 
		      <xsl:value-of select="student"/><br/>
		    </td>
		  </tr>
		  <tr>
		    <td valig="top">
		      <div class="message">
			<xsl:value-of select="centralMessage"/>
		      </div>
		    </td>

		    <td valig="top">
		      <div class="message">
			<xsl:value-of select="rightMessage"/>
		      </div>
		    </td>
		  </tr>
		</table>
		<br/>
	      <div style="height: 2em;">
		      <xsl:apply-templates select="type"/>
	      </div>
	      <br/>
	      </div>
</xsl:template>

<xsl:template match="type[text() = 'empty']">

<input type="text" name="time" size="8"/> 
<xsl:text>   </xsl:text>
<img name="redImg" src="../../icons/red.gif" border="0" height="10" width="0"/><img name="greenImg" src="../../icons/green.gif" border="0" height="10" width="500"/>


<!-- <form name="missing"> -->
<br/>
Faltam <input type="text" name="total" value="0" size="2"/> perguntas. 
<xsl:text>  </xsl:text><xsl:text>  </xsl:text><xsl:text>  </xsl:text>
Perguntas em falta 
<select size="1" name="missing" onChange="jumpMissing(this);">
<option> * escolha pergunta * </option>
</select>

<!-- </form> -->

<script language="JavaScript">
	<xsl:variable name="duration" select="//duration"/>
	SetWakeup(disableEditing);
	SetTimer(
		<xsl:value-of select="substring-before($duration,':')"/>,
		<xsl:value-of select="substring-after($duration,':')"/>,
		0);
	Start(); 
</script>

</xsl:template>


<xsl:template match="type[text() = 'answered']">

  <b>Valorização</b>: <xsl:value-of select="../value"/><br/> 
  <b>Correcção</b>: as afirmações correctas 
  estão marcadas com <span class="right"/>
<!--
estão destacadas a <b>negrito</b>
-->
  e as erradas estão marcadas com 
	    		    <span class="wrong"/>
<!--
<s>cortadas</s>. 
-->
  <xsl:if test="$print = 'yes'">
  	<br/>Assinatura: <hr/>
  </xsl:if>
</xsl:template>


<xsl:template match="quizGroup">
	      <h3><xsl:number/>. <xsl:value-of select="@title"/> <!-- [valor: <xsl:value-of select="@value"/>] --> </h3>

	      <blockquote>
	      <xsl:apply-templates select="quizQuestion"/>
	      
	      </blockquote>
</xsl:template>


<xsl:template match="quizQuestion">

	<xsl:variable name="ref"><xsl:number value="count(../preceding-sibling::node()) "/>.<xsl:number/>.</xsl:variable>
	<xsl:if test="$print = 'no' and //type!='answered'">
		<script language="JavaScript">
			declareMissing("<xsl:value-of select='$ref'/>");
		</script>
	</xsl:if>
	      <a name="{$ref}"/>	      
	      <xsl:if test="count(../quizQuestion) &gt; 1">
		<span style="margin: 1cm; font-weight:bold">
		  <xsl:value-of select="$ref"/>
		</span>
	      </xsl:if>
	      <!-- - --> 
	      <xsl:copy-of select="ask/*|ask/text()"/> 
	      <!-- [valor: <xsl:value-of select="@value"/>] -->


	      <xsl:choose>
		<xsl:when test="/quiz/header/horizontal-answers">
		  <table border="0" >
	      	      <xsl:apply-templates select="quizChoice"/>
		  </table>
		</xsl:when>
		<xsl:otherwise>
		  <table border="0" cellpadding="5" cellspacing="10">
		    <tr>
	      	      <td><xsl:apply-templates select="quizChoice"/></td>
		    </tr>
		  </table>
		</xsl:otherwise>
	      </xsl:choose>
</xsl:template>

<xsl:template match="quizChoice[//type='answered']">

	     [<xsl:choose>
	 	<xsl:when test="@selected = 'true'">
			  <xsl:text>x</xsl:text>
		</xsl:when>
		<xsl:otherwise>
			  <xsl:text>  </xsl:text>
		</xsl:otherwise>
		</xsl:choose>]
	    <xsl:choose>
	    <xsl:when test="@status='right'">
			    <span class="right"/>
	    		    <b><xsl:copy-of select="text()|*"/></b>
	     </xsl:when>
	    <xsl:when test="@status='wrong'">
	    		    <span class="wrong"/>
			    <s><xsl:copy-of select="text()|*"/></s>
	     </xsl:when>
	     <xsl:otherwise>
			    <xsl:copy-of select="text()|*"/>
	     </xsl:otherwise>
	   </xsl:choose>



	<br/>
</xsl:template>

<xsl:template match="quizChoice[//type='empty']">
	<xsl:variable name="ref"><xsl:number
	value="count(../../preceding-sibling::node()) "/>.<xsl:number value="count(../preceding-sibling::node())+1"/>.</xsl:variable>


	<xsl:choose>
	  <xsl:when test="/quiz/header/horizontal-answers">
	      <xsl:call-template name="question">
		<xsl:with-param name="ref" select="$ref"/>
		<xsl:with-param name="width" select="0"/>
	      </xsl:call-template>
	  </xsl:when>
	  <xsl:otherwise>
	    <tr>
	      <xsl:call-template name="question">
		<xsl:with-param name="ref" select="$ref"/>
	      </xsl:call-template>
	    </tr>
	  </xsl:otherwise>
	</xsl:choose>
</xsl:template>


<xsl:template name="question">
  <xsl:param name="ref"/>
  <xsl:param name="width" select="0"/>

  <td>
    <input 
       name="{@xml:id}" 
       type="checkbox" 
       value="true"
       onClick="markAsMissing('{$ref}',this.checked)"
       >
      <xsl:if test="@selected = 'true' ">
	<xsl:attribute name="checked"/>
      </xsl:if>
    </input>
  </td>
  <td width="{$width}">
    <xsl:copy-of select="text()|*"/>
    
  </td>
</xsl:template>


</xsl:transform>
