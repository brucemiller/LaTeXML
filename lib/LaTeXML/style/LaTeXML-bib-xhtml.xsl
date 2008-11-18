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
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="f"
    exclude-result-prefixes = "ltx f">

  <!-- ======================================================================
       Bibliography (AFTER conversion to presentation; ie only bibitem's)
       ====================================================================== -->

  <!-- NOTE: bibentry (and all it's components) are converted by postprocessing. -->

  <xsl:template match="ltx:biblist" xml:space="preserve">
    <ul class="{f:classes(.)}">
      <xsl:apply-templates/>
    </ul>
  </xsl:template>

  <xsl:template match="ltx:bibitem" xml:space="preserve">
    <li class="{f:classes(.)}"><xsl:call-template name="add_id"/>
      <xsl:apply-templates/>
    </li>
  </xsl:template>

  <xsl:template match="ltx:bibitem/ltx:bibtag[@role='refnum']">
    <span class="{concat(f:classes(.),' bibitem-tag')}"><xsl:value-of select="@open"/><xsl:apply-templates/><xsl:value-of select="@close"/></span>
  </xsl:template>

  <xsl:template match="ltx:bibtag"/>

  <xsl:template match="ltx:bibblock" xml:space="preserve">
    <div class="bibblock">
      <xsl:apply-templates/>
    </div>
  </xsl:template>

</xsl:stylesheet>
