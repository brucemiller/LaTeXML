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
    exclude-result-prefixes = "ltx">

  <!-- ======================================================================
       Document Structure
       ====================================================================== -->

  <xsl:template match="ltx:document  | ltx:part | ltx:chapter
		       | ltx:section | ltx:subsection | ltx:subsubsection
		       | ltx:paragraph | ltx:subparagraph
		       | ltx:bibliography | ltx:appendix | ltx:index">
    <section>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </section>
  </xsl:template>

  <xsl:template match="ltx:creator[@role='author']">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="@role"/>
      </xsl:call-template>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:personname">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='address']">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="@role"/>
      </xsl:call-template>

      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='email']">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="@role"/>
      </xsl:call-template>
      <a href="{concat('mailto:',text())}"><xsl:apply-templates/></a>
    </div>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='dedicatory']">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="@role"/>
      </xsl:call-template>

      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <!-- put in footer -->
  <xsl:template match="ltx:date"/>

  <xsl:template match="ltx:abstract">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:if test="@name">
	<h6><xsl:apply-templates select="@name"/><xsl:text>.</xsl:text></h6>
      </xsl:if>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:acknowledgements">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:if test="@name">
	<h6><xsl:apply-templates select="@name"/><xsl:text>.</xsl:text></h6>
      </xsl:if>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:keywords">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:if test="@name">
	<h6><xsl:apply-templates select="@name"/><xsl:text>:</xsl:text></h6>
      </xsl:if>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:classification">
    <xsl:text>
    </xsl:text>
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
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
    <!-- Skip title, if there's a titlepage! -->
    <xsl:if test="not(parent::*/child::ltx:titlepage)">    
      <hgroup>
	<h1>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates/>
	</h1>
	<xsl:apply-templates select="../ltx:subtitle"/>
      </hgroup>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:subtitle">
    <h2>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </h2>
  </xsl:template>

  <xsl:template match="ltx:toctitle"/>

  <!-- ======================================================================
       Indices
       ====================================================================== -->

  <xsl:template match="ltx:indexlist">
    <ul>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </ul>
  </xsl:template>

  <xsl:template match="ltx:indexentry">
    <li>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="ltx:indexphrase"/>
      <xsl:apply-templates select="ltx:indexrefs"/>
      <xsl:apply-templates select="ltx:indexlist"/>
    </li>
  </xsl:template>

  <xsl:template match="ltx:indexrefs">
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

</xsl:stylesheet>
