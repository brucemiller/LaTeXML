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
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="f"
    exclude-result-prefixes = "ltx f">

  <!-- ======================================================================
       Logical paragraphs
       ====================================================================== -->

  <xsl:template match="ltx:para">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:inline-para">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Theorems
       ====================================================================== -->

  <!-- theorem's title is in LaTeXML-structure-xhtml, where it's import precedence
       can be better managed -->
  <xsl:template match="ltx:theorem | ltx:proof">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Floating things; Figures & Tables
       ====================================================================== -->

  <xsl:template match="ltx:figure | ltx:table | ltx:float | ltx:listing">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:if($USE_HTML5,'figure','div')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:choose>
	<xsl:when test="count(ltx:figure | ltx:table | ltx:float | ltx:listing | ltx:graphics) > 1">
	  <xsl:text>&#x0A;</xsl:text>
	  <xsl:element name="table" namespace="{$html_ns}">
	    <!-- maybe even more, like display:table ? or some class ? -->
	    <xsl:attribute name="style">width:100%;</xsl:attribute>
	    <xsl:text>&#x0A;</xsl:text>
	    <xsl:element name="tr" namespace="{$html_ns}">
	      <xsl:for-each select="ltx:figure | ltx:table | ltx:float | ltx:listing | ltx:graphics">
		<xsl:text>&#x0A;</xsl:text>
		<xsl:element name="td" namespace="{$html_ns}">
		  <xsl:attribute name="class">
		    <xsl:value-of select="concat('ltx_sub',local-name(.))"/>
		  </xsl:attribute>
		  <xsl:apply-templates select="."/>
		</xsl:element>
	      </xsl:for-each>
	    </xsl:element>
	    <xsl:text>&#x0A;</xsl:text>
	  </xsl:element>
	  <xsl:apply-templates select="ltx:caption"/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:apply-templates/>
	</xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:caption">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:if($USE_HTML5,'figcaption','div')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:toccaption"/>

</xsl:stylesheet>