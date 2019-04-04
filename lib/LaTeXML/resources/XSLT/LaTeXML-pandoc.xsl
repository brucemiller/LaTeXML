<!--
/=====================================================================\
|  LaTeXML-pandoc.xsl                                                 |
|  Stylesheet for converting LaTeXML documents to Pandoc's JSON AST   |
|=====================================================================|
| Part of LaTeXML:                                                    |
|  Public domain software, produced as part of work done by the       |
|  United States Government & not subject to copyright in the US.     |
|=====================================================================|
| Released to the Public Domain                                       |
|=====================================================================|
| Deyan Ginev <deyan.ginev@gmail.com>                                 |
| Bruce Miller <bruce.miller@nist.gov>                        #_#     |
| http://dlmf.nist.gov/LaTeXML/                              (o o)    |
\=========================================================ooo==U==ooo=/

Pandoc AST as defined at:
     https://github.com/jgm/pandoc-types/blob/master/Text/Pandoc/Definition.hs#L95
-->
<xsl:stylesheet
    version   = "1.0"
    xmlns:xsl = "http://www.w3.org/1999/XSL/Transform"
    xmlns:ltx = "http://dlmf.nist.gov/LaTeXML"
    exclude-result-prefixes="ltx">

  <xsl:import href="LaTeXML-tabular-xhtml.xsl"/>
  <xsl:import href="LaTeXML-common.xsl"/>
  <xsl:strip-space elements="*"/>
	<xsl:output method="text" encoding="utf-8"/>

  <xsl:variable name="footnotes" select="//ltx:note[@role='footnote']"/>
  <xsl:template name="add_classes"/>
  <xsl:param name="html_ns"></xsl:param>

  <xsl:template match="*">
    <xsl:message> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
	<xsl:for-each select="./@*">
	  <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
	</xsl:for-each>
      </xsl:if>
      is currently not supported for the main body.
    </xsl:message>
    <xsl:comment> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
	<xsl:for-each select="./@*">
	  <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
	</xsl:for-each>
      </xsl:if>
      is currently not supported for the main body.
    </xsl:comment>
  </xsl:template>

  <xsl:template match="*" mode="math">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="math"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*" mode="math">
    <xsl:attribute name="{local-name()}"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="@xml:id" mode="math">
    <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="*" mode="front">
    <xsl:message> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
	<xsl:for-each select="./@*">
	  <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
	</xsl:for-each>
      </xsl:if>
      is currently not supported for the front matter.
    </xsl:message>
    <xsl:comment> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
	<xsl:for-each select="./@*">
	  <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
	</xsl:for-each>
      </xsl:if>
      is currently not supported for the front matter.
    </xsl:comment>
  </xsl:template>

  <xsl:template match="*" mode="back">
    <xsl:message> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
	<xsl:for-each select="./@*">
	  <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
	</xsl:for-each>
      </xsl:if>
      is currently not supported for the back matter.
    </xsl:message>
    <xsl:comment> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
	<xsl:for-each select="./@*">
	  <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
	</xsl:for-each>
      </xsl:if>
      is currently not supported for the back matter
    </xsl:comment>
  </xsl:template>

  <xsl:template match="ltx:ERROR">
    An error in the conversion from LaTeX to XML has occurred here.
  </xsl:template>

  <xsl:template match="ltx:ERROR" mode="front">
    An error in the conversion from LaTeX to XML has occurred here.
  </xsl:template>

  <xsl:template match="ltx:ERROR" mode="back">
    An error in the conversion from LaTeX to XML has occurred here.
  </xsl:template>

  <xsl:template match="ltx:document">
  {
  "pandoc-api-version": [
    1,
    17,
    4,
    2
  ],
  "blocks": [],
  "meta": {
    "date": {
      "t": "MetaInlines",
      "c": []
    },
    "author": {
      "t": "MetaList",
      "c": []
    }
  }}
	<!-- <article-meta>
	  <xsl:apply-templates select="ltx:title" mode="front"/>
	  <contrib-group>
	    <xsl:apply-templates select="ltx:creator[@role='author']" mode="front"/>
	  </contrib-group>
	  <xsl:apply-templates select="ltx:date[@role='creation']" mode="front"/>
	  <xsl:apply-templates select="ltx:abstract" mode="front"/>
	  <xsl:apply-templates select="ltx:keywords" mode="front"/>
	  <xsl:apply-templates select="*[not(self::ltx:title or self::ltx:creator[@role='author'] or self::ltx:date[@role='creation'] or self::ltx:abstract or self::ltx:keywords)]" mode="front"/>
	</article-meta> -->
	<!-- <xsl:apply-templates select="@*|node()"/> -->
	<!-- <xsl:apply-templates select="@*|node()" mode="back"/> -->
	<!-- <app-group> -->
	  <!-- <xsl:apply-templates select="//ltx:appendix" mode="app"/> -->
	<!-- </app-group> -->
  </xsl:template>
</xsl:stylesheet>
