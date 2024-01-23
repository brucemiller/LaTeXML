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

  <xsl:strip-space elements="ltx:para ltx:inline-logical-block"/>

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

  <xsl:template match="ltx:logical-block">
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

  <xsl:template match="ltx:inline-logical-block">
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
      <xsl:when test="count(*[contains(@class,'ltx_figure_panel')]) > 1">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:variable name="from_figure" select="."/>
        <!-- init: in cases we have no caption, as well as any pre-caption content -->
          <xsl:call-template name="build_subfigure">
            <xsl:with-param name="context" select="$context"/>
            <xsl:with-param name="from_figure" select="$from_figure"/>
          </xsl:call-template>
        <!-- main flex panels: partition by captions -->
        <xsl:for-each select="ltx:caption">
          <xsl:call-template name="build_subfigure">
            <xsl:with-param name="context" select="$context"/>
            <xsl:with-param name="from_caption" select="."/>
            <xsl:with-param name="from_figure" select="$from_figure"/>
          </xsl:call-template>
        </xsl:for-each>
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

  <xsl:template name="build_subfigure">
    <xsl:param name="context"/>
    <xsl:param name="from_caption"/>
    <xsl:param name="from_figure"/>
    <!-- set up any potential panels for this subfigure -->
    <xsl:variable name="from_position">
      <xsl:choose>
        <xsl:when test="$from_caption">
          <xsl:value-of select="count($from_caption/preceding-sibling::node())+2"/>
        </xsl:when>
        <xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="to_position_check">
      <xsl:choose>
        <xsl:when test="$from_caption">
          <xsl:choose>
            <xsl:when test="$from_caption/following-sibling::ltx:caption[1]">
              <xsl:value-of select="count($from_caption/following-sibling::ltx:caption[1]/preceding-sibling::node())"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="count($from_figure/node())"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="count(ltx:caption[1]/preceding-sibling::node())"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="to_position">
      <xsl:choose>
        <xsl:when test="$to_position_check>0">
          <xsl:value-of select="1+$to_position_check"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="count($from_figure/node())+1"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:message>from-to panels: <xsl:value-of select="$from_position"/>-<xsl:value-of select="$to_position"/></xsl:message>
    <xsl:variable name="nodes_in_partition"
      select="$from_figure/node()[position()&gt;=$from_position and
        position() &lt; $to_position]"/>
    <xsl:variable name="figure_panels" select="$nodes_in_partition[contains(@class,'ltx_figure_panel')]"></xsl:variable>
    <xsl:message>subfigure panels: <xsl:value-of select="count($figure_panels)"/></xsl:message>
    <!-- first prepare the caption, if any, outside of the wrapping flex div -->
    <xsl:if test="$from_caption">
      <xsl:apply-templates select="$from_caption">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:if>
    <!-- then prepare the flex subfigure(s) -->
    <xsl:choose><xsl:when test="$figure_panels">
      <xsl:variable name="panel_count_keyword">
        <xsl:choose>
          <xsl:when test="count($figure_panels)>4">many</xsl:when>
          <xsl:otherwise><xsl:value-of select="count($figure_panels)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:element name="div" namespace="{$html_ns}">
        <xsl:attribute name="class">ltx_flex_figure<!--
        --><xsl:if test="self::ltx:table"> ltx_flex_table</xsl:if>
        </xsl:attribute>
        <xsl:text>&#x0A;</xsl:text>
        <xsl:for-each select="$nodes_in_partition">
          <xsl:choose>
            <xsl:when test="self::ltx:break">
              <xsl:element name="div" namespace="{$html_ns}">
                <xsl:attribute name="class">ltx_flex_break</xsl:attribute>
              </xsl:element>
            </xsl:when>
            <xsl:when test="contains(@class,'ltx_figure_panel')">
              <xsl:element name="div" namespace="{$html_ns}">
                <xsl:attribute name="class">ltx_flex_cell ltx_flex_size_<xsl:value-of select="$panel_count_keyword"/></xsl:attribute>
                <xsl:apply-templates select=".">
                  <xsl:with-param name="context" select="$context"/>
                </xsl:apply-templates>
              </xsl:element>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select=".">
                <xsl:with-param name="context" select="$context"/>
              </xsl:apply-templates>
            </xsl:otherwise>
        </xsl:choose>
        </xsl:for-each>
      </xsl:element>
    </xsl:when>
    <xsl:otherwise>
      <xsl:for-each select="$nodes_in_partition">
        <xsl:apply-templates select=".">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:for-each>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
