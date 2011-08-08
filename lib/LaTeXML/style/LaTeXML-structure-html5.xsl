<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-structure-html5.xsl                                        |
|  Converting documents structure to html5                            |
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
       Document Structure
       ====================================================================== -->

  <xsl:template match="ltx:document  | ltx:part | ltx:chapter
		       | ltx:section | ltx:subsection | ltx:subsubsection
		       | ltx:paragraph | ltx:subparagraph
		       | ltx:bibliography | ltx:appendix | ltx:index" xml:space="preserve">
    <section class="{f:classes(.)}"><xsl:call-template name="add_id"/>
    <xsl:apply-templates/>
    </section>
  </xsl:template>

  <xsl:template match="ltx:creator[@role='author']" xml:space="preserve">
    <div class="{concat(f:classes(.),' ',@role)}"><xsl:apply-templates/></div>
  </xsl:template>

  <xsl:template match="ltx:personname" xml:space="preserve">
    <div class="{f:classes(.)}"><xsl:apply-templates/></div>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='address']" xml:space="preserve">
    <div class="{concat(f:classes(.),' ',@role)}"><xsl:apply-templates/></div>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='email']" xml:space="preserve">
    <div class="{concat(f:classes(.),' ',@role)}"><a href="{concat('mailto:',text())}"><xsl:apply-templates/></a></div>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='dedicatory']" xml:space="preserve">
    <div class="{concat(f:classes(.),' ',@role)}"><xsl:apply-templates/></div>
  </xsl:template>

  <!-- put in footer -->
  <xsl:template match="ltx:date"/>

  <xsl:template match="ltx:abstract" xml:space="preserve">
    <div class='{f:classes(.)}'>
      <xsl:if test="@name"><h6><xsl:apply-templates select="@name"/><xsl:text>.</xsl:text></h6></xsl:if>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:acknowledgements">
    <div class='{f:classes(.)}'>
      <xsl:if test="@name"><h6><xsl:apply-templates select="@name"/><xsl:text>.</xsl:text></h6></xsl:if>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:keywords" xml:space="preserve">
    <div class='{f:classes(.)}'>
      <xsl:if test="@name"><h6><xsl:apply-templates select="@name"/><xsl:text>:</xsl:text></h6></xsl:if>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:classification">
    <xsl:text>
    </xsl:text>
    <div class='{f:classes(.)}'>
      <i><xsl:choose>
	<xsl:when test='@scheme'><xsl:value-of select='@scheme'/></xsl:when>
	<xsl:when test='@name'><xsl:value-of select='@name'/></xsl:when>
      </xsl:choose>: </i>
    <xsl:apply-templates/></div>
  </xsl:template>

  <!--  ======================================================================
       Titles.
       ====================================================================== -->
  <!-- Hack to determine the `levels' of various sectioning.
       Given that the nesting could consist of any of
       document/part/chapter/section or appendix/subsection/subsubsection
       /paragraph/subparagraph
       We'd like to assign h1,h2,... sensibly.
       Or should the DTD be more specific? -->

  <xsl:param name="title_level">6</xsl:param>

  <xsl:param name="document_level">
    <xsl:value-of select="1"/>
  </xsl:param>


  <xsl:template match="ltx:title">
    <hgroup>
      <h1 class="{concat(f:classes(.),
		    f:if(@font,concat(' ',@font),''),
		    f:if(@size,concat(' ',@size),''))}"
	     style="{f:if(@color,concat('color:',@color),'')}"><xsl:apply-templates/></h1>
      <xsl:apply-templates select="../ltx:subtitle"/>
    </hgroup>
  </xsl:template>

  <xsl:template match="ltx:subtitle">
    <h2 class="{f:classes(.)}"><xsl:apply-templates/></h2>
  </xsl:template>

  <xsl:template match="ltx:toctitle"/>

  <!-- ======================================================================
       Indices
       ====================================================================== -->

  <xsl:template match="ltx:indexlist">
    <ul class="{f:classes(.)}">
      <xsl:apply-templates/>
    </ul>
  </xsl:template>

  <xsl:template match="ltx:indexentry">
    <li class="{f:classes(.)}"><xsl:call-template name="add_id"/>
    <xsl:apply-templates select="ltx:indexphrase"/>
    <xsl:apply-templates select="ltx:indexrefs"/>
    <xsl:apply-templates select="ltx:indexlist"/>
    </li>
  </xsl:template>

  <xsl:template match="ltx:indexrefs">
    <span class="{f:classes(.)}"><xsl:apply-templates/></span>
  </xsl:template>

</xsl:stylesheet>
