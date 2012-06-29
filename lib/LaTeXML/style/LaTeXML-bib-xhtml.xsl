<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-bib-xhtml.xsl                                              |
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
    exclude-result-prefixes = "ltx">

  <!-- ======================================================================
       Bibliography (AFTER conversion to presentation; ie only bibitem's)
       ====================================================================== -->

  <!-- NOTE: bibentry (and all it's components) are converted by postprocessing. -->

  <xsl:template match="ltx:biblist">
    <ul>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </ul>
  </xsl:template>

  <xsl:template match="ltx:bibitem">
    <li>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </li>
  </xsl:template>

  <xsl:template match="ltx:bibitem/ltx:bibtag[@role='refnum']">
    <span><xsl:call-template name="add_id"/><xsl:call-template name="add_attributes"
      /><xsl:value-of select="@open"/><xsl:apply-templates/><xsl:value-of select="@close"/></span>
  </xsl:template>

  <xsl:template match="ltx:bibtag"/>

  <xsl:template match="ltx:bibblock">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

</xsl:stylesheet>
