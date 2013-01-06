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
    xmlns       = "http://www.w3.org/1999/xhtml"
    xmlns:ltx   = "http://dlmf.nist.gov/LaTeXML"
    exclude-result-prefixes = "ltx">

  <!-- ======================================================================
       Typically invisible meta elements
       ====================================================================== -->

  <!-- normally hidden, but should be exposable various ways.
       The role will likely distinguish various modes of footnote, endnote,
       and other annotation -->
  <xsl:template match="ltx:note">
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="@role"/>
      </xsl:call-template>
      <xsl:call-template name="note-mark"/>
      <span class="{concat(local-name(.),'_content_outer')}">
	<span class="{concat(local-name(.),'_content')}">
	  <xsl:call-template name="note-mark"/>
	  <xsl:if test="not(@role = 'footnote')">
	    <span class="note-type"><xsl:value-of select="@role"/>: </span>
	  </xsl:if>
	  <xsl:apply-templates/>
	</span>
      </span>
    </span>
  </xsl:template>

  <xsl:template name="note-mark">
    <sup class="mark">
      <xsl:choose>
	<xsl:when test="@mark"><xsl:value-of select="@mark"/></xsl:when>
	<xsl:otherwise>&#x2020;</xsl:otherwise>
      </xsl:choose>
    </sup>
  </xsl:template>

  <!-- Actually, this ought to be annoyingly visible -->
  <xsl:template match="ltx:ERROR">
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

  <!-- The indexmark disappears -->
  <xsl:template match="ltx:indexmark"/>

  <!-- but the phrases it contains may be used in back-ref situations -->
  <xsl:template match="ltx:indexphrase">
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

  <!-- Typically will end up with css display:none -->
  <xsl:template match="ltx:rdf">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </div>
    <xsl:text>&#x0A;</xsl:text>
  </xsl:template>

</xsl:stylesheet>