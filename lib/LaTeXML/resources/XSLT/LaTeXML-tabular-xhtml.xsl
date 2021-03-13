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
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="f"
    exclude-result-prefixes = "ltx f">

  <!-- ======================================================================
       Tabulars
       ====================================================================== -->

  <!-- LaTeXML allows tabular in both block & inline contexts, but HTML does not;
       In inline contexts, we just generate span (but with appropriate CSS).
       See the CONTEXT discussion in LaTeXML-common -->

  <xsl:strip-space elements="ltx:tabular ltx:thead ltx:tbody ltx:tfoot ltx:tr"/>
  <xsl:preserve-space elements="ltx:td"/>

  <xsl:template match="ltx:tabular">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:blockelement($context,'table')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:thead">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:blockelement($context,'thead')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:tbody">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:blockelement($context,'tbody')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:tfoot">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:blockelement($context,'tfoot')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:tr">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:blockelement($context,'tr')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:td">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:blockelement($context,f:if(@thead,'th','td'))}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <!-- generally, align & width should be covered by CSS -->
      <xsl:call-template name="add_attributes">
        <xsl:with-param name="extra_classes">
          <xsl:if test="@thead">
            <xsl:value-of select="concat('ltx_th ',f:class-pref('ltx_th_',@thead))"/>
          </xsl:if>
          <xsl:if test="@thead and @border">
            <xsl:text> </xsl:text>
          </xsl:if>
          <xsl:if test="@border">
            <xsl:value-of select="f:class-pref('ltx_border_',@border)"/>
          </xsl:if>
          <!-- attempt to simulate rowspan when simulating table.
               Actually, I think we need empty <td> for the spanned cells! -->
          <xsl:if test="@rowspan and $context = 'inline'">
            <xsl:if test="@thead or @border">
              <xsl:text> </xsl:text>
            </xsl:if>
            <xsl:text>ltx_rowspan</xsl:text>
          </xsl:if>
        </xsl:with-param>
        <xsl:with-param name="extra_style">
          <xsl:if test="starts-with(@align,'char:')">
            <xsl:text>text-align:"</xsl:text>
            <xsl:value-of select="substring-after(@align,'char:')"/>
            <xsl:text>";</xsl:text>
          </xsl:if>
          <xsl:choose>
            <xsl:when test="ancestor::ltx:tabular[@rowsep and @colsep]">
              <xsl:value-of select="concat('padding:',f:half(ancestor::ltx:tabular/@rowsep),' ',
                                    ancestor::ltx:tabular/@colsep,';')"/>
            </xsl:when>
            <xsl:when test="ancestor::ltx:tabular/@rowsep">
              <xsl:value-of select="concat('padding-top:',f:half(ancestor::ltx:tabular/@rowsep),';')"/>
              <xsl:value-of select="concat('padding-bottom:',f:half(ancestor::ltx:tabular/@rowsep),';')"/>
            </xsl:when>
            <xsl:when test="ancestor::ltx:tabular/@colsep">
              <xsl:value-of select="concat('padding-left:',ancestor::ltx:tabular/@colsep,';')"/>
              <xsl:value-of select="concat('padding-right:',ancestor::ltx:tabular/@colsep,';')"/>
            </xsl:when>
          </xsl:choose>
        </xsl:with-param>
      </xsl:call-template>
      <xsl:if test="@colspan">
        <xsl:attribute name='colspan'><xsl:value-of select='@colspan'/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@rowspan">
        <xsl:attribute name='rowspan'><xsl:value-of select='@rowspan'/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
