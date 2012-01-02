<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-tabular-xhtml.xsl                                          |
|  Converting tabular to xhtml                                        |
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
     Tabulars
     ====================================================================== -->

<xsl:template match="ltx:tabular" xml:space="preserve">
  <table class="{f:classes(.)}"><xsl:call-template name="add_id"/>
    <xsl:apply-templates/>
  </table>
</xsl:template>

<xsl:template match="ltx:thead" xml:space="preserve">
  <thead class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></thead>
</xsl:template>

<xsl:template match="ltx:tbody" xml:space="preserve">
  <tbody class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></tbody>
</xsl:template>

<xsl:template match="ltx:tfoot" xml:space="preserve">
  <tfoot class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></tfoot>
</xsl:template>

<xsl:template match="ltx:tr" xml:space="preserve">
  <tr class="{f:classes(.)}"><xsl:call-template name="add_id"/><xsl:apply-templates/></tr>
</xsl:template>

<xsl:template match="ltx:td">
  <xsl:text>
</xsl:text>
  <xsl:element name="{f:if(@thead,'th','td')}"><xsl:call-template name="add_id"/>
    <xsl:if test="@colspan">
      <xsl:attribute name='colspan'><xsl:value-of select='@colspan'/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@rowspan">
      <xsl:attribute name='rowspan'><xsl:value-of select='@rowspan'/></xsl:attribute>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="starts-with(@align,'char:')">
        <xsl:attribute name='align'>char</xsl:attribute>    
        <xsl:attribute name='char'><xsl:value-of select="substring-after(@align,'char:')"/></xsl:attribute>
      </xsl:when>
      <xsl:when test="@align">
        <xsl:attribute name='align'><xsl:value-of select='@align'/></xsl:attribute>
      </xsl:when>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="@border">
        <xsl:attribute name='class'><xsl:value-of select="concat(f:classes(.),' ',@border)"/></xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name='class'><xsl:value-of select="f:classes(.)"/></xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="@width">
	<xsl:attribute name='width'><xsl:value-of select="@width"/></xsl:attribute>
      </xsl:when>
    </xsl:choose>
    <xsl:apply-templates/>
  </xsl:element>
</xsl:template>


</xsl:stylesheet>
