<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\
|  LaTeXML-xhtml5.xsl                                                 |
|  Stylesheet for converting LaTeXML documents to html5 in XML syntax |
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

  <xsl:output method     = "xml"
              encoding   = "utf-8"
              media-type = "application/xhtml+xml"/>

  <xsl:param name="USE_NAMESPACES"  >true</xsl:param>
  <xsl:param name="USE_HTML5"       >true</xsl:param>

  <!-- Note: If you want namespace prefixes (eg. for MathML & SVG),
       Redefine the root template ("/") and add prefixed namespace declarations
       (eg.xmlns:m="http://www.w3.org/1998/Math/MathML") -->

  <!-- The doctype is optional and is supposed to be ignored by parsers -->
  <xsl:template match="/" mode="doctype">
    <xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE html></xsl:text>
  </xsl:template>

</xsl:stylesheet>
