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
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="f"
    exclude-result-prefixes = "ltx f">

  <!-- ======================================================================
       Logical paragraphs
       ====================================================================== -->

  <!-- Most of these templates generate block-level elements but may appear
       in inline mode; they use f:blockelement so that they will generate
       a valid 'span' element instead.
       See the CONTEXT discussion in LaTeXML-common -->

  <xsl:strip-space elements="ltx:para ltx:inline-para"/>

  <xsl:template match="ltx:para">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:blockelement($context,'div')}" namespace="{$html_ns}">
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

  <xsl:template match="ltx:inline-para">
    <xsl:param name="context"/>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Theorems
       ====================================================================== -->

  <!-- theorem's title is in LaTeXML-structure-xhtml, where it's import precedence
       can be better managed -->
  <xsl:strip-space elements="ltx:theorem ltx:proof"/>

  <!-- Don't display tags; they're in the title -->
  <xsl:template match="ltx:theorem/ltx:tags | ltx:proof/ltx:tags"/>

  <xsl:template match="ltx:theorem | ltx:proof">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
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

  <!-- ======================================================================
       Floating things; Figures & Tables
       ====================================================================== -->

  <xsl:strip-space elements="ltx:figure ltx:table ltx:float"/>

  <!-- Don't display tags; they're in the caption -->
  <xsl:template match="ltx:figure/ltx:tags | ltx:table/ltx:tags | ltx:float/ltx:tags"/>

  <xsl:template match="ltx:figure | ltx:table | ltx:float">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:choose>
      <xsl:when test="@angle | @xtranslate | @ytranslate | @xscale | @yscale ">
        <xsl:element name="div" namespace="{$html_ns}">
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes">
            <xsl:with-param name="extra_classes" select="'ltx_transformed_outer'"/>
          </xsl:call-template>
          <xsl:element name="div" namespace="{$html_ns}">
            <xsl:attribute name="class">ltx_transformed_inner</xsl:attribute>
            <xsl:call-template name="add_transformable_attributes"/>
            <xsl:apply-templates select="." mode="begin">
              <xsl:with-param name="context" select="$context"/>
            </xsl:apply-templates>
            <xsl:element name="{f:if($USE_HTML5,f:blockelement($context,'figure'),'div')}" namespace="{$html_ns}">
              <xsl:apply-templates select="." mode="inner">
                <xsl:with-param name="context" select="$context"/>
              </xsl:apply-templates>
            </xsl:element>
          </xsl:element>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="{f:if($USE_HTML5,f:blockelement($context,'figure'),'div')}" namespace="{$html_ns}">
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes"/>
          <xsl:apply-templates select="." mode="inner">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:figure | ltx:table | ltx:float" mode="inner">
    <xsl:param name="context"/>
    <xsl:apply-templates select="." mode="begin">
      <xsl:with-param name="context" select="$context"/>
    </xsl:apply-templates>
    <xsl:choose>
      <xsl:when test="count(ltx:figure | ltx:table | ltx:float | ltx:graphics) > 1">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:apply-templates select="ltx:caption[following-sibling::ltx:figure
                                     | following-sibling::ltx:table
                                     | following-sibling::ltx:float
                                     | following-sibling::ltx:graphics]">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
        <xsl:element name="table" namespace="{$html_ns}">
          <!-- maybe even more, like display:table ? or some class ? -->
          <xsl:attribute name="style">width:100%;</xsl:attribute>
          <xsl:text>&#x0A;</xsl:text>
          <xsl:element name="tr" namespace="{$html_ns}">
            <xsl:for-each select="ltx:figure | ltx:table | ltx:float | ltx:graphics">
              <xsl:text>&#x0A;</xsl:text>
              <xsl:element name="td" namespace="{$html_ns}">
                <xsl:attribute name="class">
                  <xsl:value-of select="concat('ltx_sub',local-name(.))"/>
                </xsl:attribute>
                <xsl:apply-templates select=".">
                  <xsl:with-param name="context" select="$context"/>
                </xsl:apply-templates>
              </xsl:element>
            </xsl:for-each>
          </xsl:element>
          <xsl:text>&#x0A;</xsl:text>
        </xsl:element>
        <xsl:apply-templates select="ltx:caption[preceding-sibling::ltx:figure
                                     | preceding-sibling::ltx:table
                                     | preceding-sibling::ltx:float
                                     | preceding-sibling::ltx:graphics]">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates>
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="." mode="end">
      <xsl:with-param name="context" select="$context"/>
    </xsl:apply-templates>
    <xsl:text>&#x0A;</xsl:text>
  </xsl:template>

  <xsl:preserve-space elements="ltx:caption"/>
  <xsl:template match="ltx:caption">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:if($USE_HTML5,f:blockelement($context,'figcaption'),'div')}"
                 namespace="{$html_ns}">
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

  <xsl:preserve-space elements="ltx:toccaption"/>
  <xsl:template match="ltx:toccaption"/>

</xsl:stylesheet>
