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
    xmlns       = "http://www.w3.org/1999/xhtml"
    xmlns:ltx   = "http://dlmf.nist.gov/LaTeXML"
    exclude-result-prefixes = "ltx">

  <!-- ======================================================================
       Visible inline elements
       ====================================================================== -->

  <xsl:template match="ltx:text">
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

  <!-- Special case: all OTHER attributes have to be outside the "hidden"
       in order to take effect (eg. background color, etc).
       Note that "contains" is NOT the right test for @class....-->
  <xsl:template match="ltx:text[contains(@class,'ltx_phantom')]">
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <span style="visibility:hidden">
	<xsl:apply-templates/>
      </span>
    </span>
  </xsl:template>

  <xsl:template match="ltx:emph">
    <em>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </em>
  </xsl:template>

  <xsl:template match="ltx:del">
    <del>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </del>
  </xsl:template>

  <xsl:template match="ltx:sub">
    <sub>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </sub>
  </xsl:template>

  <xsl:template match="ltx:sup">
    <sup>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </sup>
  </xsl:template>

  <xsl:template match="ltx:acronym">
    <acronym title="{@name}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </acronym>
  </xsl:template>

  <xsl:template match="ltx:rule">
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_style">
	  <!-- Note: width doesn't affect an inline element, but we don't want to be a block -->
	  <xsl:choose>
	    <xsl:when test="@color">
	      <xsl:value-of select="concat('background:',@color,';display:inline-block;')"/>
	    </xsl:when>
	    <xsl:otherwise>background:black;display:inline-block;</xsl:otherwise>
	  </xsl:choose>
	</xsl:with-param>
      </xsl:call-template>
      <xsl:if test="string(@width)!='0.0pt'">&#xA0;</xsl:if>
    </span>
  </xsl:template>

  <xsl:template match="ltx:ref">
    <xsl:choose>
      <xsl:when test="not(@href) or @href=''">
	<span>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_classes" select="'here'"/>
	  </xsl:call-template>
	  <xsl:apply-templates/>
	</span>
      </xsl:when>
      <xsl:otherwise>
	<a href="{@href}" title="{@title}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates/>
	</a>
      </xsl:otherwise>
    </xsl:choose>    
  </xsl:template>

  <!-- can't nest-->
  <xsl:template match="ltx:ref//ltx:ref">
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

  <xsl:template match="ltx:anchor">
    <a name="{@xml:id}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <xsl:template match="ltx:cite">
    <cite>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </cite>
  </xsl:template>

  <!-- ltx:bibref not handled, since it is translated to ref in crossref module -->
    
</xsl:stylesheet>

