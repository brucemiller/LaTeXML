<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-picture-svg-html5.xsl                                      |
|  Converting pictures to SVG w/o namespaces for html5                |
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
    xmlns:m     = "http://www.w3.org/1998/Math/MathML"
    xmlns:svg   = "http://www.w3.org/2000/svg"
    exclude-result-prefixes = "ltx svg">
  
  <!-- Copy SVG, as is ???? -->
  <xsl:template match="*[namespace-uri() = 'http://www.w3.org/2000/svg']">
    <!-- A note on namespaces: Use
	 * name() for the prefixed name (see LaTeXML-xhtml for reqd xmlns:m declaration)
	 * local-name() gets the unprefixed name, but with xmlns on EACH node.
	 If you omit the namespace= on xsl:element, you get the un-namespaced name (eg.html5)-->
    <xsl:element name="{local-name()}">
      <xsl:for-each select="@*">
	<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
      </xsl:for-each>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
