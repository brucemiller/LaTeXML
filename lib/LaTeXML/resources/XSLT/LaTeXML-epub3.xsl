<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\
|  LaTeXML-epub3.xsl                                                  |
|  Stylesheet for converting LaTeXML documents to ePub3               |
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
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:epub  = "http://www.idpf.org/2007/ops"
    exclude-result-prefixes="ltx">

  <!-- Include all LaTeXML to xhtml modules -->
  <xsl:import href="LaTeXML-all-xhtml.xsl"/>

  <!-- Override the output method & parameters -->
  <xsl:output
      method = "xml"
      encoding       = 'utf-8'
      media-type     = 'application/xhtml+xml'/>

  <!-- No namespaces; DO use HTML5 elements (include MathML & SVG) -->
  <xsl:param name="USE_NAMESPACES"  >true</xsl:param>
  <xsl:param name="USE_HTML5"       >true</xsl:param>

  <!-- Do not copy the RDFa prefix, but proceed as usual -->
  <xsl:template match="/">
    <xsl:apply-templates select="." mode="doctype"/>
    <xsl:element name="html" namespace="{$html_ns}">
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:choose>
        <xsl:when test="*/@xml:lang">
          <xsl:apply-templates select="*/@xml:lang" mode="copy-attribute"/>
        </xsl:when>
        <xsl:otherwise><!-- the default language is English -->
          <xsl:attribute name="lang">en</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="." mode="head"/>
      <xsl:apply-templates select="." mode="body"/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <!-- RDFa is invalid in EPUB3, so just skip over it -->
  <xsl:template match="ltx:rdf">
  </xsl:template>

  <!-- Linking to a text/plain data URL is invalid in EPUB3,
       so just skip over it -->
  <xsl:template match="ltx:listing[@data]" mode="begin"/>

  <xsl:template match="ltx:TOC">
    <xsl:param name="context"/>
    <xsl:if test="ltx:toclist/descendant::ltx:tocentry">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="nav" namespace="{$html_ns}">
        <xsl:attribute name="epub:type">toc</xsl:attribute>
        <xsl:call-template name='add_attributes'>
          <xsl:with-param name="extra_classes" select="f:class-pref('ltx_toc_',@lists)"/>
        </xsl:call-template>
        <xsl:if test="ltx:title">
          <xsl:element name="h6" namespace="{$html_ns}">
            <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
            <xsl:attribute name="class">ltx_title ltx_title_contents</xsl:attribute>
            <xsl:apply-templates select="ltx:title/node()">
              <xsl:with-param name="context" select="$innercontext"/>
            </xsl:apply-templates>
          </xsl:element>
        </xsl:if>
        <xsl:apply-templates>
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <!-- And, probably ePub pages do not need headers or footers -->
  <xsl:template match="/" mode="header"/>
  <xsl:template match="/" mode="footer"/>

</xsl:stylesheet>
