<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-all-xhtml.xsl                                              |
|  Combine all modules for converting LaTeXML documents to xhtml      |
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

  <!-- Include all LaTeXML to xhtml modules -->
  <!-- Note that you can include these in your own stylesheet using urns like:
       <xsl:include href="urn:x-LaTeXML:XSLT:LaTeXML-common.xsl"/>
  -->

  <xsl:include href="LaTeXML-common.xsl"/>
  <xsl:include href="LaTeXML-inline-xhtml.xsl"/>
  <xsl:include href="LaTeXML-block-xhtml.xsl"/>
  <xsl:include href="LaTeXML-misc-xhtml.xsl"/>
  <xsl:include href="LaTeXML-meta-xhtml.xsl"/>
  <xsl:include href="LaTeXML-para-xhtml.xsl"/>
  <xsl:include href="LaTeXML-math-xhtml.xsl"/>
  <xsl:include href="LaTeXML-tabular-xhtml.xsl"/>
  <xsl:include href="LaTeXML-picture-xhtml.xsl"/>
  <xsl:include href="LaTeXML-structure-xhtml.xsl"/>
  <xsl:include href="LaTeXML-bib-xhtml.xsl"/>
  <xsl:include href="LaTeXML-webpage-xhtml.xsl"/>
</xsl:stylesheet>
