<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-bib-xhtml.xsl                                              |
|  Converting documents structure to xhtml                            |
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

  <!-- whether to split bibliography lists into two columns -->
  <xsl:param name="twocolumn-biblist"></xsl:param>

  <!-- ======================================================================
       Bibliography
       [AFTER conversion to presentation by postprocessing! ie only bibitem's]
       ====================================================================== -->

  <xsl:template match="ltx:biblist">
    <xsl:choose>
      <xsl:when test="$twocolumn-biblist">
	<xsl:apply-templates select="." mode="twocolumns"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:text>&#x0A;</xsl:text>
	<xsl:element name="ul" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	  <xsl:text>&#x0A;</xsl:text>
	</xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:biblist" mode="twocolumns">
    <xsl:param name="items"    select="ltx:bibitem"/>
    <xsl:param name="lines"    select="ltx:bibitem/ltx:bibblock | ltx:bibitem"/>
    <xsl:param name="halflines" select="ceiling(count($lines) div 2)"/>
    <xsl:param name="miditem" select="count($lines[position() &lt; $halflines]/parent::*) + 1"/>
    <xsl:call-template name="split-columns">
      <xsl:with-param name="wrapper" select="'ul'"/>
      <xsl:with-param name="items"   select="$items"/>
      <xsl:with-param name="miditem" select="$miditem"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="ltx:bibitem">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="li" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <!-- potential future parameterization?
       choose which bibtag is used to display? -->
  <xsl:template match="ltx:bibitem/ltx:bibtag[@role='refnum']">
    <xsl:element name="span" namespace="{$html_ns}">
	<xsl:call-template name="add_id"/>
	<xsl:call-template name="add_attributes"/>
	<xsl:apply-templates select="." mode="begin"/>
	<xsl:value-of select="@open"/>
	<xsl:apply-templates/>
	<xsl:value-of select="@close"/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:bibtag"/>

  <!-- By default, I suppose, this should generate a span,
       but if you want openbib, use css: .ltx_bibblock{display:block;} -->
  <xsl:template match="ltx:bibblock">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
