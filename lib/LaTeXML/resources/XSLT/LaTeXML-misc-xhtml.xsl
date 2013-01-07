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
    xmlns       = "http://www.w3.org/1999/xhtml"
    xmlns:func  = "http://exslt.org/functions"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="func f"
    exclude-result-prefixes = "ltx func f">

  <!-- ======================================================================
       Various things that aren't clearly inline or blocks, or can be both
       ====================================================================== -->

  <!-- Need to handle attributes! -->
  <xsl:template match="ltx:inline-block">
    <xsl:text>&#x0A;</xsl:text>
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
      <xsl:text>&#x0A;</xsl:text>
    </div>
  </xsl:template>

  <xsl:template match="ltx:verbatim">
    <xsl:choose>
      <xsl:when test="contains(text(),'&#xA;')">
	<pre>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates/>
	</pre>
      </xsl:when>
      <xsl:otherwise>
	<code>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates/>
	</code>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:break">
    <xsl:text>&#x0A;</xsl:text>
    <br><xsl:call-template name="add_attributes"/></br>
  </xsl:template>

  <!-- ======================================================================
       Graphics inclusions
       ====================================================================== -->

  <xsl:template match="ltx:graphics">
    <img src="{@imagesrc}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_style">
	  <xsl:if test="@imagedepth">
	    <xsl:value-of select="concat('vertical-align:-',@imagedepth,'px')"/>
	  </xsl:if>
	</xsl:with-param>
      </xsl:call-template>
      <xsl:if test="@imagewidth">
	<xsl:attribute name='width'><xsl:value-of select="@imagewidth"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@imageheight">
	<xsl:attribute name='height'><xsl:value-of select="@imageheight"/></xsl:attribute>
      </xsl:if>
      <xsl:choose>
	<xsl:when test="../ltx:figure/ltx:caption">
	  <xsl:attribute name='alt'><xsl:value-of select="../ltx:figure/ltx:caption/text()"/></xsl:attribute>
	</xsl:when>
	<xsl:when test="@description">
	  <xsl:attribute name='alt'><xsl:value-of select="@description"/></xsl:attribute>
	</xsl:when>
      </xsl:choose>
    </img>
  </xsl:template>

  <!-- ======================================================================
       Passing Raw HTML thru
       ====================================================================== -->

  <xsl:template match="ltx:rawhtml">
    <xsl:apply-templates mode="raw"/>
  </xsl:template>

  <xsl:template match="*" mode="raw">
    <xsl:element name="{local-name()}">
      <xsl:for-each select="@*">
	<xsl:attribute name="{name()}">
	  <xsl:value-of select="."/>
	</xsl:attribute>
      </xsl:for-each>
      <xsl:apply-templates mode="raw"/>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       SVG Handled in its own module.
       ====================================================================== -->

</xsl:stylesheet>