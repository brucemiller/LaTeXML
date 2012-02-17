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

    <!-- A note on namespaces: In <xlt:element name="{???}", use
	 * name() to get the prefixed name (see LaTeXML-xhtml for reqd xmlns:m declaration)
	 * local-name() gets the unprefixed name, but with xmlns on EACH node.
	 If you omit the namespace= on xsl:element, you get the un-namespaced name (eg.html5)-->

  <!-- Copy MathML, as is -->
  <xsl:template match="*[namespace-uri() = 'http://www.w3.org/1998/Math/MathML']">
    <xsl:element name="{local-name()}" namespace='http://www.w3.org/1998/Math/MathML'>
      <xsl:for-each select="@*">
	<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
      </xsl:for-each>
      <xsl:choose>
	<!-- If annotation-xml in a DIFFERENT namespace, do blind copy
	     (staying in this template for mathml in annotation avoids extra ns declarations 
	     in old libxslt) -->
        <xsl:when test="local-name()='annotation-xml'                              
                        and not(namespace-uri(child::*) = 'http://www.w3.org/1998/Math/MathML')">
	  <xsl:apply-templates mode='blind-copy'/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:apply-templates/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- This copies WHATEVER, in WHATEVER namespace (eg. OpenMath, or....)
       I'm thinking that using local-name(), here, is best,
       to avoid namespace prefixes altogether -->
  <xsl:template match="*" mode='blind-copy'>
    <xsl:element name="{local-name()}" namespace="{namespace-uri()}">
      <xsl:for-each select="@*">
	<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
      </xsl:for-each>
      <xsl:apply-templates mode='blind-copy'/>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
