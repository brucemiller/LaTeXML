<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-html.xsl                                                   |
|  Stylesheet for converting LaTeXML documents to html                |
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
    version   = "1.0"
    xmlns:xsl = "http://www.w3.org/1999/XSL/Transform"
    xmlns:ltx = "http://dlmf.nist.gov/LaTeXML"
    exclude-result-prefixes="ltx">

  <xsl:output
      method = "html"
      omit-xml-declaration = 'yes'
      doctype-public = "-//W3C//DTD HTML 4.01//EN"
      doctype-system = "http://www.w3.org/TR/html4/strict.dtd"
      media-type     = 'text/html'
      encoding       = 'utf-8'
      indent         = 'yes'/>

  <xsl:template name="metatype">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
  </xsl:template>

  <xsl:template name="add_id">
    <!-- Is this safe now?
    <xsl:if test="@fragid">
      <a name="{@fragid}"></a>
    </xsl:if>
    -->
    <xsl:attribute name="id"><xsl:value-of select="@fragid"/></xsl:attribute>
  </xsl:template>

  <xsl:template match="/">
    <html>
      <xsl:call-template name="head"/>
      <xsl:call-template name="body"/>
    </html>
  </xsl:template>

<xsl:include href="LaTeXML-common.xsl"/>
<xsl:include href="LaTeXML-inline-html.xsl"/>
<xsl:include href="LaTeXML-block-html.xsl"/>
<xsl:include href="LaTeXML-para-html.xsl"/>
<xsl:include href="LaTeXML-math-image.xsl"/>
<xsl:include href="LaTeXML-tabular-html.xsl"/>
<xsl:include href="LaTeXML-picture-image.xsl"/>
<xsl:include href="LaTeXML-structure-html.xsl"/>
<xsl:include href="LaTeXML-bib-html.xsl"/>

<xsl:include href="LaTeXML-webpage-html.xsl"/>

</xsl:stylesheet>
