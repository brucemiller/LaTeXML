<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-math-mathml.xsl                                            |
|  copy MathML for xhtml                                              |
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
    xmlns:xlink = "http://www.w3.org/1999/xlink"
    exclude-result-prefixes = "ltx">

  <xsl:template match="ltx:Math">
    <xsl:apply-templates select="m:math"/>
  </xsl:template>

  <!-- Copy MathML, as is -->
  <xsl:template match="*[namespace-uri() = 'http://www.w3.org/1998/Math/MathML']">
    <xsl:element name="{name()}" namespace='http://www.w3.org/1998/Math/MathML'>
      <xsl:for-each select="@*">
	<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
      </xsl:for-each>
      <!-- firefox needs the xlink:type attribute -->
      <xsl:if test="@*[namespace-uri() = 'http://www.w3.org/1999/xlink'] and not(@xlink:type)">
	<xsl:attribute name="type" namespace='http://www.w3.org/1999/xlink'>simple</xsl:attribute>
      </xsl:if>

      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
