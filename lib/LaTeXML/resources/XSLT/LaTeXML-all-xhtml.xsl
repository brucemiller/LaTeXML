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
       <xsl:import href="urn:x-LaTeXML:XSLT:LaTeXML-common.xsl"/>
  -->

  <xsl:import href="LaTeXML-common.xsl"/>
  <xsl:import href="LaTeXML-inline-xhtml.xsl"/>
  <xsl:import href="LaTeXML-block-xhtml.xsl"/>
  <xsl:import href="LaTeXML-misc-xhtml.xsl"/>
  <xsl:import href="LaTeXML-meta-xhtml.xsl"/>
  <xsl:import href="LaTeXML-para-xhtml.xsl"/>
  <xsl:import href="LaTeXML-math-xhtml.xsl"/>
  <xsl:import href="LaTeXML-tabular-xhtml.xsl"/>
  <xsl:import href="LaTeXML-picture-xhtml.xsl"/>
  <xsl:import href="LaTeXML-structure-xhtml.xsl"/>
  <xsl:import href="LaTeXML-bib-xhtml.xsl"/>
  <xsl:import href="LaTeXML-webpage-xhtml.xsl"/>
</xsl:stylesheet>
