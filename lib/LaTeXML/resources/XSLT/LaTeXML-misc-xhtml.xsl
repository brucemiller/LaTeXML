<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\
|  LaTeXML-misc-xhtml.xsl                                             |
|  Converting various inline/block-level elements to xhtml            |
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
    xmlns:func  = "http://exslt.org/functions"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="func f"
    exclude-result-prefixes = "ltx func f">

  <!-- ======================================================================
       Various things that aren't clearly inline or blocks, or can be both:
       ltx:inline-block, ltx:verbatim, ltx:break, ltx:graphics, ltx:svg, ltx:rawhtml
       ====================================================================== -->

  <!-- Only a few generated elements need $context switches.
       See the CONTEXT discussion in LaTeXML-common -->

  <xsl:strip-space elements="ltx:inline-block"/>

  <!-- Note that html does NOT have an inline-block element; so we must
       continue in an inline context (probably generating span's inside),
       but CSS will hopefully set appropriate display properties.
       BUT, let's only do that if we're actually in an inline context!
       In block context, just make a div-->
  <xsl:template match="ltx:inline-block">
    <xsl:param name="context"/>
    <!-- bug in libxslt!?!?!? putting these in the 'correct' place gives redefinition error! -->
    <xsl:text>&#x0A;</xsl:text>
    <xsl:choose>
      <xsl:when test="@angle | @xtranslate | @ytranslate | @xscale | @yscale ">
        <xsl:element name="{f:blockelement($context,'div')}" namespace="{$html_ns}">
          <!--<xsl:variable name="innercontext" select="'inline'"/>--><!-- override -->
          <xsl:variable name="innercontext" select="$context"/><!-- override -->
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes">
            <xsl:with-param name="extra_classes" select="'ltx_transformed_outer'"/>
          </xsl:call-template>
          <xsl:element name="span" namespace="{$html_ns}">
            <xsl:attribute name="class">ltx_transformed_inner</xsl:attribute>
            <xsl:call-template name="add_transformable_attributes"/>
            <xsl:apply-templates select="." mode="begin">
              <xsl:with-param name="context" select="$innercontext"/>
            </xsl:apply-templates>
            <xsl:apply-templates>
              <xsl:with-param name="context" select="$innercontext"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="." mode="end">
              <xsl:with-param name="context" select="$innercontext"/>
            </xsl:apply-templates>
            <xsl:text>&#x0A;</xsl:text>
          </xsl:element>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
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
          <xsl:text>&#x0A;</xsl:text>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:verbatim">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="contains(text(),'&#xA;')">
        <xsl:element name="pre" namespace="{$html_ns}">
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
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="code" namespace="{$html_ns}">
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
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:break">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="br" namespace="{$html_ns}">
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Graphics inclusions
       ====================================================================== -->

  <xsl:template match="ltx:graphics">
    <xsl:param name="context"/>
    <xsl:element name="img" namespace="{$html_ns}">
      <xsl:attribute name="src"><xsl:value-of select="f:url(@imagesrc)"/></xsl:attribute>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
        <xsl:with-param name="extra_style">
          <xsl:if test="@imagedepth">
            <xsl:value-of select="concat('vertical-align:-',@imagedepth,'px')"/>
          </xsl:if>
        </xsl:with-param>
      </xsl:call-template>
      <xsl:if test="@imagewidth">
        <xsl:attribute name='width'>
          <xsl:value-of select="@imagewidth"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="@imageheight">
        <xsl:attribute name='height'>
          <xsl:value-of select="@imageheight"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="@description">
          <xsl:attribute name='alt'>
            <xsl:value-of select="@description"/>
          </xsl:attribute>
        </xsl:when>
        <xsl:when test="ancestor::ltx:figure/ltx:caption">
          <xsl:attribute name='alt'>
            <xsl:value-of select="ancestor::ltx:figure/ltx:caption/text()"/>
          </xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name='alt'></xsl:attribute> <!--required; what else? -->
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <!-- svg graphics should use the object tag, rather than img,
       to preserve any interactivity. -->
  <xsl:template match="ltx:graphics[f:ends-with(@imagesrc,'.svg')='true']">
    <xsl:param name="context"/>
    <xsl:variable name="description">
      <xsl:choose>
        <xsl:when test="@description">
          <xsl:value-of select="@description"/>
        </xsl:when>
        <xsl:when test="ancestor::ltx:figure/ltx:caption">
            <xsl:value-of select="ancestor::ltx:figure/ltx:caption/text()"/>
        </xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:element name="object" namespace="{$html_ns}">
      <xsl:attribute name="type">image/svg+xml</xsl:attribute>
      <xsl:attribute name="data"><xsl:value-of select="f:url(@imagesrc)"/></xsl:attribute>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
        <xsl:with-param name="extra_style">
          <xsl:if test="@imagedepth">
            <xsl:value-of select="concat('vertical-align:-',@imagedepth,'px')"/>
          </xsl:if>
        </xsl:with-param>
      </xsl:call-template>
      <xsl:if test="@imagewidth">
        <xsl:attribute name='width'>
          <xsl:value-of select="@imagewidth"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="@imageheight">
        <xsl:attribute name='height'>
          <xsl:value-of select="@imageheight"/>
        </xsl:attribute>
      </xsl:if>
      <!-- the object tag does not support alt, so use
           aria-label instead -->
      <xsl:if test="$description!=''">
        <xsl:attribute name='aria-label'>
          <xsl:value-of select="$description"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <!-- fallback text for screen reader/browser combinations
           which do not accept the aria-label -->
      <xsl:if test="$description!=''">
        <xsl:element name="{f:blockelement($context,'p')}" namespace="{$html_ns}">
          <xsl:value-of select="$description"/>
        </xsl:element>
      </xsl:if>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Passing Raw HTML thru
       ====================================================================== -->

  <xsl:template match="ltx:rawhtml">
    <xsl:apply-templates mode="copy-foreign"/>
  </xsl:template>

  <xsl:template match="ltx:rawliteral">
    <xsl:text disable-output-escaping="yes">&lt;</xsl:text>
    <xsl:value-of select="@open"/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="text()"/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="@close"/>
    <xsl:text disable-output-escaping="yes">&gt;</xsl:text>
  </xsl:template>

  <!-- ======================================================================
       SVG Handled in its own module.
       ====================================================================== -->

</xsl:stylesheet>
