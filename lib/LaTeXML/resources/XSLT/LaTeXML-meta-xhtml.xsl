<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\
|  LaTeXML-meta-xhtml.xsl                                             |
|  Converting various meta-level elements to xhtml                    |
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
    extension-element-prefixes="f"
    exclude-result-prefixes = "ltx f">

  <!-- ======================================================================
       Typically invisible meta elements
       ltx:note, ltx:indexmark, ltx:rdf, ltx:ERROR
       ====================================================================== -->

  <!-- Only a few generated elements need $context switches.
       See the CONTEXT discussion in LaTeXML-common -->

  <!-- normally hidden, but should be exposable various ways.
       The role will likely distinguish various modes of footnote, endnote,
       and other annotation -->
  <xsl:preserve-space elements="ltx:note"/>
  <xsl:template match="ltx:note">
    <xsl:param name="context"/>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:call-template name="note-mark">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:call-template>
      <xsl:element name="span" namespace="{$html_ns}">
        <xsl:attribute name="class">ltx_note_outer</xsl:attribute>
        <xsl:element name="span" namespace="{$html_ns}">
          <xsl:attribute name="class">ltx_note_content</xsl:attribute>
          <xsl:call-template name="note-mark">
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:call-template>
          <xsl:if test="not(@role = 'footnote')">
            <xsl:element name="span" namespace="{$html_ns}">
              <xsl:attribute name="class">ltx_note_type</xsl:attribute>
              <xsl:value-of select="@role"/>
              <xsl:text>: </xsl:text>
            </xsl:element>
          </xsl:if>
          <xsl:apply-templates>
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="." mode="end">
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <xsl:preserve-space elements="ltx:note-mark"/>
  <xsl:template name="note-mark">
    <xsl:element name="sup" namespace="{$html_ns}">
      <xsl:attribute name="class">ltx_note_mark</xsl:attribute>
      <xsl:choose>
        <xsl:when test="ltx:tags/ltx:tag[not(@role)]"><xsl:value-of select="ltx:tags/ltx:tag[not(@role)]"/></xsl:when>
        <xsl:when test="@mark"><xsl:value-of select="@mark"/></xsl:when>
        <xsl:otherwise>&#x2020;</xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- disappears -->
  <xsl:template match="ltx:declare"/>

  <!-- Actually, this ought to be annoyingly visible -->
  <xsl:preserve-space elements="ltx:ERROR"/>
  <xsl:template match="ltx:ERROR">
    <xsl:param name="context"/>
    <xsl:element name="span" namespace="{$html_ns}">
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
    </xsl:element>
  </xsl:template>

  <!-- The indexmark disappears -->
  <xsl:template match="ltx:indexmark"/>

  <!-- but the phrases it contains may be used in back-ref situations -->
  <xsl:preserve-space elements="ltx:indexphrase"/>
  <xsl:template match="ltx:indexphrase">
    <xsl:param name="context"/>
    <xsl:element name="span" namespace="{$html_ns}">
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
    </xsl:element>
  </xsl:template>

  <!-- Typically will end up with css display:none -->
  <xsl:preserve-space elements="ltx:rdf"/>
  <xsl:template match="ltx:rdf">
    <xsl:param name="context"/>
    <xsl:element name="{f:blockelement($context,'div')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
    <xsl:text>&#x0A;</xsl:text>
  </xsl:template>

</xsl:stylesheet>
