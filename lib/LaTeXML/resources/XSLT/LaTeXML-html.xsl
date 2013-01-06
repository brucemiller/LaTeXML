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

  <xsl:template match="/">
    <html>
      <xsl:call-template name="add_RDFa_prefix"/>
      <xsl:call-template name="head"/>
      <xsl:call-template name="body"/>
      <xsl:text>&#x0A;</xsl:text>
    </html>
  </xsl:template>

  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-common.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-inline-html.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-block-html.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-misc-html.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-meta-html.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-para-html.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-math-image.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-tabular-html.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-picture-image.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-structure-html.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-bib-html.xsl"/>
  <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-webpage-html.xsl"/>

</xsl:stylesheet>
