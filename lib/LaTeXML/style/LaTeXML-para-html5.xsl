<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-para-html5.xsl                                             |
|  Converting various (logical) para-level elements to html5          |
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
    exclude-result-prefixes = "ltx">

  <!-- ======================================================================
       Logical paragraphs
       ====================================================================== -->

  <xsl:template match="ltx:para">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <!-- Need to handle attributes! -->
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
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <!-- ======================================================================
       Figures & Tables
       ====================================================================== -->

  <xsl:template match="ltx:figure | ltx:table | ltx:float | ltx:listing">
    <figure>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:choose>
	<xsl:when test="count(ltx:figure | ltx:table | ltx:float | ltx:listing | ltx:graphics) > 1">
	  <table style="width:100%;">
	    <tr>
	      <xsl:for-each select="ltx:figure | ltx:table | ltx:float | ltx:listing | ltx:graphics">
		<td><xsl:apply-templates select="."/></td>
	      </xsl:for-each>
	    </tr>
	  </table>
	  <xsl:apply-templates select="ltx:caption"/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:apply-templates/>
	</xsl:otherwise>
      </xsl:choose>
    </figure>
  </xsl:template>

  <xsl:template match="ltx:listing/ltx:tabular">
    <table>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </table>
  </xsl:template>

  <xsl:template match="ltx:caption">
    <figcaption>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </figcaption>
  </xsl:template>

  <xsl:template match="ltx:toccaption"/>

</xsl:stylesheet>