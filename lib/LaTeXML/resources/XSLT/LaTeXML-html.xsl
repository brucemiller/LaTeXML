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

  <!-- Include all LaTeXML to xhtml modules -->
  <xsl:import href="LaTeXML-all-xhtml.xsl"/>

  <!-- Override the output method & parameters -->
  <xsl:output
      method = "html"
      omit-xml-declaration = 'yes'
      doctype-public = "-//W3C//DTD HTML 4.01//EN"
      doctype-system = "http://www.w3.org/TR/html4/strict.dtd"
      media-type     = 'text/html'
      encoding       = 'utf-8'/>

  <!-- No namespaces -->
  <xsl:param name="USE_NAMESPACES"></xsl:param>
  <!-- do not use html5 elements, MathML nor SVG -->
  <xsl:param name="USE_HTML5"     ></xsl:param>
  <xsl:param name="USE_MathML"    ></xsl:param>
  <xsl:param name="USE_SVG"       ></xsl:param>

</xsl:stylesheet>
