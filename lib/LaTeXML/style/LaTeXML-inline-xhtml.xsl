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
    xmlns:func  = "http://exslt.org/functions"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    exclude-result-prefixes = "ltx func f">

<!-- ======================================================================
     Visible inline elements
     ====================================================================== -->

<xsl:template match="ltx:text">
 <span style="{f:positioning(.)}" class="{concat(f:classes(.),
					 f:if(@font,concat(' ',@font),''),
					 f:if(@size,concat(' ',@size),''))}">
   <xsl:call-template name="add_id"/>
   <xsl:apply-templates/>
 </span>
</xsl:template>

<xsl:template match="ltx:emph">
  <em class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></em>
</xsl:template>

<xsl:template match="ltx:acronym">
  <acronym class='{f:classes(.)}' title="{@name}"><xsl:call-template name="add_id"/><xsl:apply-templates/></acronym>
</xsl:template>


<!-- This should either get some sort of style w/width,height & background,
     or, at most, only be an hr if it's wide & short -->
<xsl:template match="ltx:rule">
  <span style="{concat(f:positioning(.),'background:black; ')}" class="{f:classes(.)}">&#xA0;</span>
</xsl:template>

<xsl:template match="ltx:ref">
  <xsl:choose>
    <xsl:when test="not(@href) or @href=''">
      <span class="{concat(f:classes(.),' here')}"><xsl:call-template name="add_id"/><xsl:apply-templates/></span>
    </xsl:when>
    <xsl:otherwise>
      <a href="{@href}" title="{@title}" class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></a>
    </xsl:otherwise>
  </xsl:choose>    
</xsl:template>

<!-- can't nest-->
<xsl:template match="ltx:ref//ltx:ref">
  <span class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></span>
</xsl:template>

<xsl:template match="ltx:anchor">
  <a name="{@xml:id}" class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></a>
</xsl:template>

<xsl:template match="ltx:cite">
  <cite class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></cite>
</xsl:template>

<!-- ltx:bibref not handled, since it is translated to ref in crossref module -->

<!-- ======================================================================
     Typically invisible meta elements
     ====================================================================== -->

<!-- normally hidden -->
<xsl:template match="ltx:note">
  <span class="{concat(f:classes(.),' ',@role)}">
    <xsl:call-template name="add_id"/>
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

<xsl:template match="ltx:ERROR">
  <span class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></span>
</xsl:template>

<!-- invisible -->
<xsl:template match="ltx:indexmark"/>

<xsl:template match="ltx:indexphrase">
  <span class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></span>
</xsl:template>

</xsl:stylesheet>

