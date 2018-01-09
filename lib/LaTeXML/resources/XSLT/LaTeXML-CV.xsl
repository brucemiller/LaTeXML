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
    version   = "1.0"
    xmlns:xsl = "http://www.w3.org/1999/XSL/Transform"
    xmlns:ltx = "http://dlmf.nist.gov/LaTeXML"
    exclude-result-prefixes="ltx">

  <!-- Include all LaTeXML to xhtml modules -->
  <xsl:import href="urn:x-LaTeXML:XSLT:LaTeXML-all-xhtml.xsl"/>
  <xsl:import href="urn:x-LaTeXML:XSLT:LaTeXML-structure-xhtml.xsl"/>
  <!-- Override the output method & parameters -->
  <xsl:output
      method = "html"
      omit-xml-declaration="yes"
      encoding       = 'utf-8'
      media-type     = 'text/html'/>

  <!-- No namespaces; DO use HTML5 elements (include MathML & SVG) -->
  <xsl:param name="USE_NAMESPACES"  ></xsl:param>
  <xsl:param name="USE_HTML5"       >true</xsl:param>

  <xsl:template match="/" mode="doctype">
    <xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE html></xsl:text>
  </xsl:template>

  <xsl:template match="ltx:break">
    <xsl:text disable-output-escaping="yes">&lt;br class="ltx_break"/&gt;</xsl:text>
  </xsl:template>

  <!-- We probably need a reactive Bootstrap stylesheet as a separate entity -->
   <xsl:template match="ltx:contact">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:attribute name="class">
        <xsl:value-of select="concat('test ltx_contact_', @role)" />
      </xsl:attribute>
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:creator">
    <div class="container">
      <div class="col-md-3">
        <h1 class="author-name">
          <xsl:value-of select="ltx:contact[@role='firstname']" />
          <xsl:text> </xsl:text>
          <xsl:value-of select="ltx:contact[@role='familyname']" />
        </h1>
        <h3 class="author-title">
          <xsl:copy>
            <xsl:apply-templates select="/ltx:document/ltx:title/ltx:inline-block" />
          </xsl:copy>
        </h3>
      </div>
      <div class="col-md-3">
      </div>
      <div class="col-md-6">
        <h4 class="author-contact">
          <xsl:copy>
            <xsl:apply-templates select="ltx:contact[@role='address']" />
          </xsl:copy>
          <br class="ltx_break"/>
          <xsl:copy>
            <xsl:apply-templates select="ltx:contact[@role='mobile']" />
          </xsl:copy>
          <br class="ltx_break"/>
          <xsl:copy>
            <xsl:apply-templates select="ltx:contact[@role='email']" />
          </xsl:copy>
          <br class="ltx_break"/>
          <xsl:copy>
            <xsl:apply-templates select="ltx:contact[@role='homepage']" />
          </xsl:copy>
        </h4>
      </div>
    
    </div>

  </xsl:template>

  <xsl:template match="/ltx:document/ltx:title"></xsl:template>

</xsl:stylesheet>
