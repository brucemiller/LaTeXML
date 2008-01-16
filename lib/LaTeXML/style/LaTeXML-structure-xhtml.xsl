<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-structure-xhtml.xsl                                        |
|  Converting documents structure to xhtml                            |
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
  <div class="{f:classes(.)}"><xsl:call-template name="add_id"/>
    <xsl:apply-templates/>
  </div>
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
     <h6>Abstract. </h6>
     <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="ltx:acknowledgements">
  <div class='{f:classes(.)}'>
     <h6>Acknowledgements. </h6>
     <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="ltx:keywords" xml:space="preserve">
  <div class='{f:classes(.)}'><i>Keywords: </i><xsl:apply-templates/></div>
</xsl:template>

<xsl:template match="ltx:classification">
  <xsl:text>
  </xsl:text>
  <div class='{f:classes(.)}'>
  <i><xsl:choose>
    <xsl:when test='@scheme'><xsl:value-of select='@scheme'/></xsl:when>
    <xsl:otherwise>Classification</xsl:otherwise>
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
<xsl:param name="title_prefix"></xsl:param>

<xsl:param name="document_level">
  <xsl:value-of select="number(boolean(ltx:document))"/>
</xsl:param>

<xsl:param name="part_level">
  <xsl:value-of select="$document_level+number(boolean(//ltx:part))"/>
</xsl:param>

<xsl:param name="chapter_level">
  <xsl:value-of select="$part_level+number(boolean(//ltx:chapter))"/>
</xsl:param>

<xsl:param name="section_level">
  <xsl:value-of select="$chapter_level+number(boolean(//ltx:section | //ltx:appendix | //ltx:index | //ltx:bibliography))"/>
</xsl:param>

<xsl:param name="subsection_level">
  <xsl:value-of select="$section_level+number(boolean(//ltx:subsection))"/>
</xsl:param>

<xsl:param name="subsubsection_level">
  <xsl:value-of select="$subsection_level+number(boolean(//ltx:subsubsection))"/>
</xsl:param>

<xsl:param name="paragraph_level">
  <xsl:value-of select="$subsubsection_level+number(boolean(//ltx:paragraph))"/>
</xsl:param>

<xsl:param name="subparagraph_level">
  <xsl:value-of select="$paragraph_level+number(boolean(//ltx:subparagraph))"/>
</xsl:param>

<!-- NOTE: Work out a cleaner way to do this (?)
     AND propogate classes appropriately! -->

<xsl:template match="ltx:document/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$document_level"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:part/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$part_level"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:chapter/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$chapter_level"/>
    <xsl:with-param name="title_prefix">Chapter </xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:section/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$section_level"/>
    <xsl:with-param name="title_prefix">&#xA7;</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:bibliography/ltx:title | ltx:index/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$section_level"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:appendix/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$section_level"/>
    <xsl:with-param name="title_prefix">Appendix</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:subsection/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$subsection_level"/>
    <xsl:with-param name="title_prefix">&#xA7;</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:subsubsection/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$subsubsection_level"/>
    <xsl:with-param name="title_prefix">&#xA7;</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:paragraph/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$paragraph_level"/>
    <xsl:with-param name="title_prefix">&#xB6;</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:subparagraph/ltx:title">
  <xsl:call-template name="maketitle">
    <xsl:with-param name="title_level" select="$subparagraph_level"/>
    <xsl:with-param name="title_level" select="$paragraph_level"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="ltx:title">
  <xsl:call-template name="maketitle"/>
</xsl:template>

<!-- Convert a title to an <H#>, with appropriate classes and content
     Should prefix come from an extra attribute? -->
<xsl:template name="maketitle">
  <xsl:param name="title_level">6</xsl:param>
  <xsl:param name="title_prefix"></xsl:param>
  <xsl:param name="use_level">
    <xsl:choose>
      <xsl:when test="$title_level &gt; 6">6</xsl:when>
      <xsl:otherwise><xsl:value-of select="$title_level"/></xsl:otherwise>
    </xsl:choose>
  </xsl:param>
  <xsl:element name="{concat('h',$use_level)}">
    <xsl:attribute name="class">
      <xsl:value-of select="concat(f:classes(.),' ',concat(local-name(..),'-title'))"/>
    </xsl:attribute>
    <xsl:if test="$title_prefix"><xsl:value-of select="$title_prefix"/><xsl:text> </xsl:text></xsl:if>
    <xsl:if test="../@refnum and not(../@refnum = '')">
      <xsl:apply-templates select="../@refnum"/>.<xsl:text> </xsl:text>
    </xsl:if>
    <xsl:apply-templates/>
  </xsl:element>
</xsl:template>

<xsl:template match="ltx:toctitle"/>

<xsl:template match="ltx:subtitle">
  <div class="{f:classes(.)}"><xsl:apply-templates/></div>
</xsl:template>

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
