<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-inline-xhtml.xsl                                           |
|  Converting various inline-level elements to xhtml                  |
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
       Various inline-level elements:
       ltx:text, ltx:emph, ltx:del, ltx:sub, ltx:sup, ltx:acronym, ltx:rule,
       ltx:anchor, ltx:ref, ltx:cite, ltx:bibref
       ====================================================================== -->

  <xsl:template match="ltx:text">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <!-- Special case: all OTHER attributes have to be outside the "hidden"
       in order to take effect (eg. background color, etc).
       Note that "contains" is NOT the right test for @class....-->
  <xsl:template match="ltx:text[contains(@class,'ltx_phantom')]">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:element name="span" namespace="{$html_ns}">
	<xsl:attribute name="style">visibility:hidden</xsl:attribute>
	<xsl:apply-templates select="." mode="begin"/>
	<xsl:apply-templates/>
	<xsl:apply-templates select="." mode="end"/>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:emph">
    <xsl:element name="em" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:del">
    <xsl:element name="del" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:sub">
    <xsl:element name="sub" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:sup">
    <xsl:element name="sup" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:acronym">
    <xsl:element name="acronym" namespace="{$html_ns}">
      <xsl:attribute name="title"><xsl:value-of select="@name"/></xsl:attribute>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:rule" mode="styling">
    <xsl:apply-imports/>
    <xsl:choose>
      <xsl:when test="@color">
	<xsl:value-of select="concat('background:',@color,';display:inline-block;')"/>
      </xsl:when>
      <!-- Note: width doesn't affect an inline element, but we don't want to be a block -->
      <xsl:otherwise>background:black;display:inline-block;</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:rule">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:if test="string(@width)!='0.0pt'">&#xA0;</xsl:if>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:ref">
    <xsl:choose>
      <xsl:when test="not(@href) or @href=''">
	<xsl:element name="span" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_classes" select="'ltx_ref_self'"/>
	  </xsl:call-template>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	</xsl:element>
      </xsl:when>
      <xsl:otherwise>
	<xsl:element name="a" namespace="{$html_ns}">
	  <xsl:attribute name="href"><xsl:value-of select="f:url(@href)"/></xsl:attribute>
	  <xsl:attribute name="title"><xsl:value-of select="@title"/></xsl:attribute>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	</xsl:element>
      </xsl:otherwise>
    </xsl:choose>    
  </xsl:template>

  <xsl:template match="ltx:ref//ltx:ref">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:anchor">
    <xsl:element name="a" namespace="{$html_ns}">
      <xsl:attribute name="name"><xsl:value-of select="@xml:id"/></xsl:attribute>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:cite">
    <xsl:element name="cite" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <!-- ltx:bibref not handled, since it is translated to ref in crossref module -->
    
</xsl:stylesheet>

