<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-para-xhtml.xsl                                             |
|  Converting various (logical) para-level elements to xhtml          |
|=====================================================================|
| Part of LaTeXML:                                                    |
|  Public domain software, produced as part of work done by the       |
|  United States Government & not subject to copyright in the US.     |
|=====================================================================|
| Bruce Miller <bruce.miller@nist.gov>                        #_#     |
| http://dlmf.nist.gov/LaTeXML/                              (o o)    |
\=========================================================ooo==U==ooo=/
-->
<xsl:stylesheet
    version     = "1.0"
    xmlns:xsl   = "http://www.w3.org/1999/XSL/Transform"
    xmlns:ltx   = "http://dlmf.nist.gov/LaTeXML"
    xmlns       = "http://www.w3.org/1999/xhtml"
    exclude-result-prefixes = "ltx">

  <!-- ======================================================================
       Logical paragraphs
       ====================================================================== -->

  <xsl:template match="ltx:para">
    <xsl:text>&#x0A;</xsl:text>
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
      <xsl:text>&#x0A;</xsl:text>
    </div>
  </xsl:template>

  <xsl:template match="ltx:inline-para">
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

  <!-- ======================================================================
       Theorems
       ====================================================================== -->

  <xsl:template match="ltx:theorem | ltx:proof">
    <xsl:text>&#x0A;</xsl:text>
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
      <xsl:text>&#x0A;</xsl:text>
    </div>
  </xsl:template>

  <!-- ======================================================================
       Figures & Tables
       ====================================================================== -->

  <xsl:template match="ltx:figure | ltx:table | ltx:float | ltx:listing">
    <xsl:text>&#x0A;</xsl:text>
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:choose>
	<xsl:when test="count(ltx:figure | ltx:table | ltx:float | ltx:listing | ltx:graphics) > 1">
	  <xsl:text>&#x0A;</xsl:text>
	  <table style="width:100%;">
	    <xsl:text>&#x0A;</xsl:text>
	    <tr>
	      <xsl:for-each select="ltx:figure | ltx:table | ltx:float | ltx:listing | ltx:graphics">
		<xsl:text>&#x0A;</xsl:text>
		<td><xsl:apply-templates select="."/></td>
	      </xsl:for-each>
	    </tr>
	    <xsl:text>&#x0A;</xsl:text>
	  </table>
	  <xsl:apply-templates select="ltx:caption"/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:apply-templates/>
	</xsl:otherwise>
      </xsl:choose>
      <xsl:text>&#x0A;</xsl:text>
    </div>
  </xsl:template>

  <xsl:template match="ltx:listing/ltx:tabular">
    <xsl:text>&#x0A;</xsl:text>
    <table>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
      <xsl:text>&#x0A;</xsl:text>
    </table>
  </xsl:template>

  <xsl:template match="ltx:caption">
    <xsl:text>&#x0A;</xsl:text>
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
      <xsl:text>&#x0A;</xsl:text>
    </div>
  </xsl:template>

  <xsl:template match="ltx:toccaption"/>

</xsl:stylesheet>