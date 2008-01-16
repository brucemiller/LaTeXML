<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-xhtml.xsl                                                  |
|  Stylesheet for converting LaTeXML documents to xhtml               |
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
    xmlns:m     = "http://www.w3.org/1998/Math/MathML"
    xmlns:svg   = "http://www.w3.org/2000/svg"
    exclude-result-prefixes = "ltx">

  <xsl:output method="xml"
	      doctype-public = "-//W3C//DTD XHTML 1.1 plus MathML 2.0//EN"
	      doctype-system = "http://www.w3c.org/TR/MathML2/dtd/xhtml-math11-f.dtd"
	      media-type     = 'application/xhtml+xml'
	      encoding       = 'utf-8'
	      indent         = "yes"/>
  
  <xsl:template name="add_id">
    <xsl:if test="@fragid">
      <xsl:attribute name="id"><xsl:value-of select="@fragid"/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <xsl:template match="/">
    <html xmlns     = "http://www.w3.org/1999/xhtml"
	  xmlns:m   = "http://www.w3.org/1998/Math/MathML"
	  xmlns:svg = "http://www.w3.org/2000/svg">
      <xsl:call-template name="head"/>
      <xsl:call-template name="body"/><xsl:text>
    </xsl:text>
    </html>
  </xsl:template>

<xsl:include href="LaTeXML-common.xsl"/>
<xsl:include href="LaTeXML-inline-xhtml.xsl"/>
<xsl:include href="LaTeXML-block-xhtml.xsl"/>
<xsl:include href="LaTeXML-para-xhtml.xsl"/>
<xsl:include href="LaTeXML-math-mathml.xsl"/>
<xsl:include href="LaTeXML-tabular-xhtml.xsl"/>
<xsl:include href="LaTeXML-picture-svg.xsl"/>
<xsl:include href="LaTeXML-structure-xhtml.xsl"/>
<xsl:include href="LaTeXML-bib-xhtml.xsl"/>

<xsl:include href="LaTeXML-webpage-xhtml.xsl"/>

</xsl:stylesheet>
