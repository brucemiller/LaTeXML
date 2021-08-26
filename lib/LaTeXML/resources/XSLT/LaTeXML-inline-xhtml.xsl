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
       ltx:text, ltx:emph, ltx:del, ltx:sub, ltx:sup, ltx:rule,
       ltx:anchor, ltx:ref, ltx:cite, ltx:bibref
       ====================================================================== -->

  <!-- Most of these templates generate elements that format thier contents
       in inline mode, and so set the inner context to 'inline'.
       See the CONTEXT discussion in LaTeXML-common -->

  <xsl:preserve-space elements="ltx:text"/>
  <xsl:template match="ltx:text">
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

  <!-- Special case: all OTHER attributes have to be outside the "hidden"
       in order to take effect (eg. background color, etc).
       Note that "contains" is NOT the right test for @class....-->
  <xsl:template match="ltx:text[contains(@class,'ltx_phantom')]">
    <xsl:param name="context"/>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:element name="span" namespace="{$html_ns}">
        <xsl:attribute name="style">visibility:hidden</xsl:attribute>
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
    </xsl:element>
  </xsl:template>

  <xsl:preserve-space elements="ltx:emph"/>
  <xsl:template match="ltx:emph">
    <xsl:param name="context"/>
    <xsl:element name="em" namespace="{$html_ns}">
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

  <xsl:preserve-space elements="ltx:del"/>
  <xsl:template match="ltx:del">
    <xsl:param name="context"/>
    <xsl:element name="del" namespace="{$html_ns}">
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

  <xsl:preserve-space elements="ltx:sub"/>
  <xsl:template match="ltx:sub">
    <xsl:param name="context"/>
    <xsl:element name="sub" namespace="{$html_ns}">
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

  <xsl:preserve-space elements="ltx:sup"/>
  <xsl:template match="ltx:sup">
    <xsl:param name="context"/>
    <xsl:element name="sup" namespace="{$html_ns}">
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

  <xsl:template match="ltx:glossarydefinition"/>

  <xsl:preserve-space elements="ltx:glossaryref"/>
  <xsl:template match="ltx:glossaryref[@href]">
    <xsl:param name="context"/>
    <xsl:element name="a" namespace="{$html_ns}">
      <xsl:attribute name="href"><xsl:value-of select="f:url(@href)"/></xsl:attribute>
      <xsl:apply-templates select="." mode="inner">
        <xsl:with-param name="context" select="context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:glossaryref">
    <xsl:param name="context"/>
    <xsl:apply-templates select="." mode="inner">
      <xsl:with-param name="context" select="context"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="ltx:glossaryref" mode="inner">
    <xsl:param name="context"/>
    <xsl:element name="{f:if(contains(@show,'short'),'abbr','span')}" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:if test="@href">
        <xsl:attribute name="href"><xsl:value-of select="f:url(@href)"/></xsl:attribute>
      </xsl:if>
      <xsl:attribute name="title"><xsl:value-of select="@title"/></xsl:attribute>
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

  <xsl:template match="ltx:rule" mode="styling">
    <xsl:param name="context"/>
    <xsl:apply-templates select="." mode="base-styling"/>
    <xsl:choose>
      <xsl:when test="@color">
        <xsl:value-of select="concat('background:',@color,';display:inline-block;')"/>
      </xsl:when>
      <!-- Note: width doesn't affect an inline element, but we don't want to be a block -->
      <xsl:otherwise>background:black;display:inline-block;</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:rule">
    <xsl:param name="context"/>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:if test="string(@width)!='0.0pt'">&#xA0;</xsl:if>
    </xsl:element>
  </xsl:template>

  <xsl:preserve-space elements="ltx:ref"/>
  <xsl:template match="ltx:ref">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="not(@href) or @href='' or contains(@class,'ltx_nolink')">
        <xsl:element name="span" namespace="{$html_ns}">
          <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes">
            <xsl:with-param name="extra_classes" select="'ltx_ref_self'"/>
          </xsl:call-template>
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
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="a" namespace="{$html_ns}">
          <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
          <xsl:attribute name="href"><xsl:value-of select="f:url(@href)"/></xsl:attribute>
          <xsl:attribute name="title"><xsl:value-of select="@title"/></xsl:attribute>
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
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:ref//ltx:ref">
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

  <xsl:preserve-space elements="ltx:anchor"/>
  <xsl:template match="ltx:anchor">
    <xsl:param name="context"/>
    <xsl:element name="a" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:attribute name="name"><xsl:value-of select="@xml:id"/></xsl:attribute>
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

  <!-- avoid empty cite's from nocite -->
  <xsl:preserve-space elements="ltx:cite"/>
  <xsl:template match="ltx:cite"/>
  <xsl:template match="ltx:cite[child::*[not(self::ltx:bibref) or @show!='nothing']]">
    <xsl:param name="context"/>
    <xsl:element name="cite" namespace="{$html_ns}">
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

  <!-- ltx:bibref not handled, since it is translated to ref in crossref module -->

</xsl:stylesheet>
