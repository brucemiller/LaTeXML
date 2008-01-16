<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-para-xhtml.xsl                                             |
|  Converting various (logical) para-level elements to xhtml          |
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
     Logical paragraphs
     ====================================================================== -->

<xsl:template match="ltx:para" xml:space="preserve">
  <div class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></div>
</xsl:template>

<!-- ======================================================================
     Theorems
     ====================================================================== -->

<xsl:template match="ltx:theorem | ltx:proof" xml:space="preserve">
  <div class='{f:classes(.)}'><xsl:call-template name="add_id"/>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="ltx:theorem/ltx:title | ltx:proof/ltx:title" xml:space="preserve">
  <h6 class='{f:classes(.)}'><xsl:apply-templates/></h6>
</xsl:template>

<!-- ======================================================================
     Figures & Tables
     ====================================================================== -->

<xsl:template match="ltx:figure | ltx:table" xml:space="preserve">
  <div class='{f:classes(.)}'><xsl:call-template name="add_id"/><xsl:apply-templates/></div>
</xsl:template>

<xsl:template match="ltx:figure/ltx:caption" xml:space="preserve">
  <div class='{f:classes(.)}'>
    <xsl:if test="../@refnum">
      Figure <xsl:apply-templates select="../@refnum"/><xsl:text>. </xsl:text>
    </xsl:if>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="ltx:table/ltx:caption" xml:space="preserve">
  <div class='{f:classes(.)}'>  
    <xsl:if test="../@refnum">
      Table <xsl:apply-templates select="../@refnum"/><xsl:text>. </xsl:text>
    </xsl:if>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="ltx:toccaption"/>

</xsl:stylesheet>