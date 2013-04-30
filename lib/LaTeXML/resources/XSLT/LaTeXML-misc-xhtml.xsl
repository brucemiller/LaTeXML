<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-misc-xhtml.xsl                                             |
|  Converting various inline/block-level elements to xhtml            |
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
    xmlns:func  = "http://exslt.org/functions"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="func f"
    exclude-result-prefixes = "ltx func f">

  <!-- ======================================================================
       Various things that aren't clearly inline or blocks, or can be both:
       ltx:inline-block, ltx:verbatim, ltx:break, ltx:graphics, ltx:svg, ltx:rawhtml
       ====================================================================== -->

  <!-- Need to handle attributes! -->
  <xsl:template match="ltx:inline-block">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:verbatim">
    <xsl:choose>
      <xsl:when test="contains(text(),'&#xA;')">
	<xsl:element name="pre" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	</xsl:element>
      </xsl:when>
      <xsl:otherwise>
	<xsl:element name="code" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	</xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:break">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="br" namespace="{$html_ns}">
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Graphics inclusions
       ====================================================================== -->

  <xsl:template match="ltx:graphics">
    <xsl:element name="img" namespace="{$html_ns}">
      <xsl:attribute name="src"><xsl:value-of select="f:url(@imagesrc)"/></xsl:attribute>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_style">
	  <xsl:if test="@imagedepth">
	    <xsl:value-of select="concat('vertical-align:-',@imagedepth,'px')"/>
	  </xsl:if>
	</xsl:with-param>
      </xsl:call-template>
      <xsl:if test="@imagewidth">
	<xsl:attribute name='width'>
	  <xsl:value-of select="@imagewidth"/>
	</xsl:attribute>
      </xsl:if>
      <xsl:if test="@imageheight">
	<xsl:attribute name='height'>
	  <xsl:value-of select="@imageheight"/>
	</xsl:attribute>
      </xsl:if>
      <xsl:choose>
	<xsl:when test="@description">
	  <xsl:attribute name='alt'>
	    <xsl:value-of select="@description"/>
	  </xsl:attribute>
	</xsl:when>
	<xsl:when test="../ltx:figure/ltx:caption">
	  <xsl:attribute name='alt'>
	    <xsl:value-of select="../ltx:figure/ltx:caption/text()"/>
	  </xsl:attribute>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:attribute name='alt'></xsl:attribute> <!--required; what else? -->
	</xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Passing Raw HTML thru
       ====================================================================== -->

  <xsl:template match="ltx:rawhtml">
    <xsl:apply-templates mode="copy-foreign"/>
  </xsl:template>

  <xsl:template match="ltx:rawliteral">
    <xsl:text disable-output-escaping="yes">&lt;</xsl:text>
    <xsl:value-of select="@open"/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="text()"/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="@close"/>
    <xsl:text disable-output-escaping="yes">&gt;</xsl:text>
  </xsl:template>

  <!-- ======================================================================
       SVG Handled in its own module.
       ====================================================================== -->

</xsl:stylesheet>
