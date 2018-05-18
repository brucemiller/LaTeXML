<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  Common utility functions for stylesheet; for inclusion             |
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
    xmlns:exsl  = "http://exslt.org/common"
    xmlns:string= "http://exslt.org/strings"
    xmlns:date  = "http://exslt.org/dates-and-times"
    xmlns:func  = "http://exslt.org/functions"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:xhtml = "http://www.w3.org/1999/xhtml"
    extension-element-prefixes="func f exsl string date"
    exclude-result-prefixes = "ltx f func string">

  <!-- ALL CAPS parameters are intended to be passed in;
       lower case ones are (mostly) intended for internal use-->

  <!-- ======================================================================
       Parameters -->
  <!-- The version of LaTeXML being used; for generator messages. -->
  <xsl:param name="LATEXML_VERSION"></xsl:param>

  <!-- A string indicating the date and time of document generation or processing. -->
  <xsl:param name="TIMESTAMP"></xsl:param>

  <!-- What version of RDFa to generate. [Set to "1.0" for broken behaviour] -->
  <xsl:param name="RDFA_VERSION"></xsl:param>

  <!-- Whether to use Namespaces in the generated xml/xhtml/...-->  
  <xsl:param name="USE_NAMESPACES">true</xsl:param>
  
  <!-- Whether to use HTML5 constructs in the generated html. -->
  <xsl:param name="USE_HTML5"></xsl:param>
 
  <!-- The XHTML namespace -->
  <xsl:param name="XHTML_NAMESPACE">http://www.w3.org/1999/xhtml</xsl:param>

  <!-- Whether to use xml:id instead of plain ole id;
       Not sure if we ever should; probably depends on embedded schema, as well? -->  
  <xsl:param name="USE_XMLID"></xsl:param>

  <!-- The namespace to use on html elements (typically XHTML_NAMESPACE or none) -->
  <xsl:param name="html_ns">
    <xsl:value-of select="f:if($USE_NAMESPACES,$XHTML_NAMESPACE,'')"/>
  </xsl:param>

  <!-- ======================================================================
       LaTeXML Identification
       (Maybe bring the Logo back?)
  -->
  <xsl:template name="LaTeXML_identifier">
    <xsl:if test="$LATEXML_VERSION or $TIMESTAMP">
      <xsl:comment>
        <xsl:text>Generated</xsl:text>
        <xsl:if test="$TIMESTAMP">
          <xsl:text> on </xsl:text>
          <xsl:value-of select="$TIMESTAMP"/>
        </xsl:if>
        <xsl:text> by LaTeXML</xsl:text>
        <xsl:if test="$LATEXML_VERSION">
          <xsl:text> (version </xsl:text>
          <xsl:value-of select="$LATEXML_VERSION"/>
          <xsl:text>)</xsl:text>
        </xsl:if>
        <xsl:text> http://dlmf.nist.gov/LaTeXML/.</xsl:text>
      </xsl:comment>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:if>
    <xsl:if test="//ltx:date[@role='creation' or @role='conversion'][1]">
      <xsl:comment>
        <xsl:text>Document created on </xsl:text>
        <xsl:value-of select='//ltx:date/node()'/>
        <xsl:text>.</xsl:text>
      </xsl:comment>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- ======================================================================
       Customization Hooks (for redefinition)
       These are called in each (non-trivial) template within the main result element,
       before and after the content is processed.
       They are sorta "inner" begin & end.
       "Outer" begin & end is easy to do using <xsl:apply-imports/>
  -->
  <xsl:template match="*|/" mode="begin"/>
  <xsl:template match="*|/" mode="end"/>

  <!-- ======================================================================
       Utility functions
  -->
  <!-- Three-way if as function: f:if(test,iftrue,iffalse)
       Returns either the iftrue or iffalse branch, depending on test. -->
  <func:function name="f:if">
    <xsl:param name="test"/>
    <xsl:param name="iftrue"/>
    <xsl:param name="iffalse"/>
    <xsl:choose>
      <xsl:when test="$test"><func:result><xsl:value-of select="$iftrue"/></func:result></xsl:when>
      <xsl:otherwise><func:result><xsl:value-of select="$iffalse"/></func:result></xsl:otherwise>
    </xsl:choose>
  </func:function>

  <func:function name="f:min">
    <xsl:param name="a"/>
    <xsl:param name="b"/>
    <xsl:choose>
      <xsl:when test="$a &lt; $b"><func:result><xsl:value-of select="$a"/></func:result></xsl:when>
      <xsl:otherwise><func:result><xsl:value-of select="$b"/></func:result></xsl:otherwise>
    </xsl:choose>
  </func:function>

  <func:function name="f:max">
    <xsl:param name="a"/>
    <xsl:param name="b"/>
    <xsl:choose>
      <xsl:when test="$a > $b"><func:result><xsl:value-of select="$a"/></func:result></xsl:when>
      <xsl:otherwise><func:result><xsl:value-of select="$b"/></func:result></xsl:otherwise>
    </xsl:choose>
  </func:function>

  <func:function name="f:ends-with">
    <xsl:param name="string"/>
    <xsl:param name="ending"/>
    <func:result>
      <xsl:value-of select="substring($string,string-length($string) - string-length($ending)+1)
                            = $ending"/>
    </func:result>
  </func:function>

  <!-- Process a url
       HOOK: This is provided as a hook for any rewriting (eg. relativizing)
       you may want to do with href values.
  -->
  <func:function name="f:url">
    <xsl:param name="url"/>
    <func:result><xsl:value-of select="$url"/></func:result>
  </func:function>

  <func:function name="f:class-pref">
    <xsl:param name="prefix"/>
    <xsl:param name="string"/>
    <func:result>
      <xsl:value-of select="f:class-pref-aux($prefix,normalize-space($string))"/>
    </func:result>
  </func:function>

  <func:function name="f:class-pref-aux">
    <xsl:param name="prefix"/>
    <xsl:param name="string"/>
    <func:result>
      <xsl:choose>
        <xsl:when test="$string = ''"></xsl:when>
        <xsl:when test="contains($string,' ')">
          <xsl:value-of select="concat($prefix,substring-before($string,' '),
                                ' ',f:class-pref-aux($prefix,substring-after($string,' ')))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($prefix,$string)"/>
        </xsl:otherwise>
      </xsl:choose>
    </func:result>
  </func:function>

  <func:function name="f:subst">
    <xsl:param name="string"/>
    <xsl:param name="pattern"/>
    <xsl:param name="replacement"/>
    <xsl:choose>
      <xsl:when test="contains($string,$pattern)">
        <func:result><xsl:value-of
        select="concat(substring-before($string,$pattern),
                       $replacement,
                       f:subst(substring-after($string,$pattern),$pattern,$replacement))"/>
        </func:result>
      </xsl:when>
      <xsl:otherwise>
        <func:result><xsl:value-of select="$string"/></func:result>
      </xsl:otherwise>
    </xsl:choose>
  </func:function>

  <!-- ======================================================================
       CONTEXT
       Note that LaTeXML's schema (modeled after latex) is more permissive about
       'miscellaneous' elements (such as tables, inline-blocks, etc) within
       inline context than HTML/HTML5. More than a validity problem, HTML5 parsers
       will rewrite the DOM to suit itself, resulting in flawed display.
       Virtually all LaTeXML templates take a 'context' parameter that should be either
       'inline' or (currently) anything else. Templates that generate elements
       that only accept inline markup should pass $context 'inline' to templates
       called or applied within.  Any block level templates (that expect to be
       used in such a context) should accomodate by using
       f:blockelement($context,'element')
       where 'element' is the html element they would normally generate.
       If this is used in an inline context, 'span' will be used instead,
       maintaining validity and avoiding DOM rewrites.
       Presumably there will be an appropriate class ltx_XXX css on the element
       which will set the display property appropriately.
  -->
  <func:function name="f:blockelement">
    <xsl:param name="context"/>
    <xsl:param name="blocktag"/>
    <xsl:choose>
      <xsl:when test="$context = 'inline'">
        <func:result>span</func:result>
      </xsl:when>
      <xsl:otherwise>
        <func:result><xsl:value-of select="$blocktag"/></func:result>
      </xsl:otherwise>
    </xsl:choose>
  </func:function>

  <!-- ======================================================================
       Dimension utilities
       [hopefully only see units of px or pt?
  -->
  
  <func:function name="f:adddim">
    <xsl:param name="value1"/>
    <xsl:param name="value2"/>
    <func:result>
      <xsl:value-of select="concat(f:dimpx($value1)+f:dimpx($value2),'px')"/>
      </func:result>
  </func:function>

  <func:function name="f:halfdiff">
    <xsl:param name="value1"/>
    <xsl:param name="value2"/>
    <func:result>
      <xsl:value-of select="concat((f:dimpx($value1)-f:dimpx($value2)) div 2,'px')"/>
      </func:result>
  </func:function>

  <func:function name="f:half">
    <xsl:param name="value"/>
    <func:result>
      <xsl:value-of select="concat(f:dimpx($value) div 2,'px')"/>
      </func:result>
  </func:function>


  <func:function name="f:dimpx">
    <xsl:param name="value"/>
    <func:result>
      <xsl:choose>
        <xsl:when test="contains($value,'px')">
          <xsl:value-of select="number(substring-before($value,'px'))"/>
        </xsl:when>
        <xsl:when test="contains($value,'pt')">
          <xsl:value-of select="number(substring-before($value,'pt'))*100 div 72"/>
        </xsl:when>
        <!-- other units? -->
        <xsl:otherwise>
          <xsl:value-of select="0"/>
        </xsl:otherwise>
      </xsl:choose>
    </func:result>
  </func:function>

  <func:function name="f:negate">
    <xsl:param name="value"/>
    <func:result>
      <xsl:choose>
        <xsl:when test="starts-with($value,'-')">
          <xsl:value-of select="substring-after($value,'-')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('-',$value)"/>
        </xsl:otherwise>
      </xsl:choose>
    </func:result>
  </func:function>

  <!-- ======================================================================
       Utility Templates
  -->

  <!-- Add an attribute to the current node, but only if the value is non-empty -->
  <xsl:template name="add_attribute">
    <xsl:param name="name"/>
    <xsl:param name="value"/>
    <xsl:if test="not($value = '')">
      <xsl:attribute name="{$name}"><xsl:value-of select="$value"/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- This copies WHATEVER, in WHATEVER namespace.
       It's useful for MathML's annotation-xml, or SVG's foreignObject or similar.
       We use local-name() & namespace to try avoid namespace prefixes.
       But note that namespaced attributes WILL still be preserved.
       INCLUDING xml:id; not sure if html5 really accepts that,
       but it doesn't really accept arbitrary annotations, anyway.

       If copy-foreign templates hit latexml, svg or mathml,
       they'll resume with the normal templates.
  -->
  <xsl:template match="*" mode='copy-foreign'>
    <xsl:param name="context"/>
    <xsl:element name="{local-name()}" namespace="{namespace-uri()}">
      <xsl:for-each select="@*">
        <xsl:apply-templates select="." mode="copy-attribute"/>
      </xsl:for-each>
      <xsl:apply-templates mode='copy-foreign'>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <!-- Assume we'll want to keep comments (may be important for script, eg)-->
  <xsl:template match="comment()" mode="copy-foreign">
    <xsl:comment><xsl:value-of select="."/></xsl:comment>
  </xsl:template>

  <!-- Assume that xhtml will be copied using same scheme as the generated html -->
  <xsl:template match="xhtml:*" mode='copy-foreign'>
    <xsl:element name="{local-name()}" namespace="{$html_ns}">
      <xsl:for-each select="@*">
        <xsl:apply-templates select="." mode="copy-attribute"/>
      </xsl:for-each>
      <xsl:apply-templates mode='copy-foreign'/>
    </xsl:element>
  </xsl:template>

  <!-- Embedded latexml, however, gets treated with the usual templates! -->
  <xsl:template match="ltx:*" mode='copy-foreign'>
    <xsl:param name="context"/>
    <xsl:apply-templates select="." >
      <xsl:with-param name="context"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- However, XMath elements appearing in an annotation (eg) should also be copied literally-->
  <xsl:template match="ltx:XMath | ltx:XMApp | ltx:XMTok | ltx:XMRef | ltx:XMHint
                       | ltx:XMArg | ltx:XMWrap | ltx:XMDual | ltx:XMText
                       | ltx:XMArray | ltx:XMRow | ltx:XMCell" mode='copy-foreign'>
    <xsl:element name="{local-name()}" namespace="{namespace-uri()}">
      <xsl:for-each select="@*">
        <xsl:apply-templates select="." mode="copy-attribute"/>
      </xsl:for-each>
      <xsl:apply-templates mode='copy-foreign'/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="@*" mode='copy-attribute'>
    <xsl:attribute name="{local-name()}" namespace="{namespace-uri()}">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="@xml:id" mode='copy-attribute'>
    <xsl:attribute name="{f:if($USE_XMLID,'xml:id','id')}">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="@xml:lang" mode='copy-attribute'>
    <xsl:attribute name="{f:if($USE_XMLID,'xml:lang','lang')}">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

  <!-- this is risky, assuming we know which are urls...-->
  <xsl:template match="@href | @src | @action" mode='copy-attribute'>
    <xsl:attribute name="{local-name()}">
      <xsl:value-of select="f:url(.)"/>
    </xsl:attribute>
  </xsl:template>

  <!-- ======================================================================
       Common Attribute procedures
  -->

  <!-- Copy ID info from latexml elements to generated element.
       Note that it would be tempting to include this in add_attributes (below),
       since they appear almost always together. But there are cases (eg. column splits)
       where the id should appear only once, and other attributes might be copied onto several.-->
  <xsl:template name="add_id">
    <xsl:if test="@fragid">
      <xsl:attribute name="id"><xsl:value-of select="@fragid"/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- Add the various common attributes to the html element being generated
       according to the attributes of the context node.
       This is an entry point for extensibilty.
       Would be nice if we could make provision for "extra classes",
       then we could incorporate the class attribute, as well.
       -->
  <xsl:template name="add_attributes">
    <xsl:param name="extra_classes" select="''"/>
    <xsl:param name="extra_style" select="''"/>
    <xsl:call-template name="add_classes">
      <xsl:with-param name="extra_classes" select="string($extra_classes)"/>
    </xsl:call-template>
    <xsl:call-template name="add_style">
      <xsl:with-param name="extra_style" select="string($extra_style)"/>
    </xsl:call-template>
    <xsl:apply-templates select="." mode="add_RDFa"/>
  </xsl:template>
      
  <!-- Add a class attribute value to the current html element
       according to the attributes of the context element:
       * the element name (this should be prefixed somehow!!!)
       * the class attribute
       * attributes in the Fontable.attribute set
       * content passed in via the parameter $extra_classes.

       HOOKS: 
       (1) override by defining a more specific template with mode="classes"
       that applies templates with mode="base-classes".
       [ <xsl:apply-imports/> would be more elegant, but Xalan apparently doesn't
       see an IMPORTED template that calls <xsl:apply-imports/> ???]
       (2) pass in parameter $extra_classes
  -->
  <xsl:template name="add_classes">
    <xsl:param name="extra_classes" select="''"/>
    <xsl:call-template name="add_attribute">
      <xsl:with-param name="name" select="'class'"/>
      <xsl:with-param name="value">
        <xsl:apply-templates select="." mode="classes"/>
        <xsl:if test="$extra_classes and ($extra_classes != '')">
          <xsl:text> </xsl:text>
          <xsl:value-of select="$extra_classes"/>
        </xsl:if>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="*" mode="classes">
    <xsl:apply-templates select="." mode="base-classes"/>
  </xsl:template>

  <xsl:template match="*" mode="base-classes">
    <xsl:value-of select="concat('ltx_',local-name(.))"/>
    <xsl:if test="@class">
      <xsl:value-of select="concat(' ',@class)"/> <!--Whatever strings that were given! -->
    </xsl:if>
    <xsl:if test="@font">
      <xsl:value-of select="concat(' ',f:class-pref('ltx_font_',@font))"/>
    </xsl:if>
    <xsl:if test="@role">
      <xsl:value-of select="concat(' ',f:class-pref('ltx_role_',@role))"/>
    </xsl:if>
    <xsl:if test="@align">
      <xsl:value-of select="concat(' ',f:class-pref('ltx_align_',@align))"/>
    </xsl:if>
    <xsl:if test="@vattach">
      <xsl:value-of select="concat(' ',f:class-pref('ltx_align_',@vattach))"/>
    </xsl:if>
    <xsl:if test="@float">
      <xsl:value-of select="concat(' ',f:class-pref('ltx_align_float',@float))"/>
    </xsl:if>
    <xsl:if test="@framed">
      <xsl:value-of select="concat(' ',f:class-pref('ltx_framed_',@framed))"/>
    </xsl:if>
  </xsl:template>

  <!-- Add a CSS style attribute to the current html element
       according to attributes of the context node.
       * Positionable.attributes
       * Colorable.attributes

       Note that width & height (& padding versions)
       will be ignored in most cases... silly CSS.
       Note that some attributes clash because they're setting
       the same CSS property; there's no combining here (yet?).   

       HOOKS: 
       (1) override by defining a more specific template with mode="classes"
       that applies templates with mode="base-styling".
       (2) pass in parameter $extra_style
  -->
  <xsl:template name="add_style">
    <xsl:param name="extra_style" select="''"/>
    <xsl:call-template name="add_attribute">
      <xsl:with-param name="name" select="'style'"/>
      <xsl:with-param name="value">
        <xsl:apply-templates select="." mode="styling"/>
        <xsl:if test="$extra_style">
          <xsl:value-of select="$extra_style"/>
        </xsl:if>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="*" mode="styling">
    <xsl:apply-templates select="." mode="base-styling"/>
  </xsl:template>

  <xsl:template match="*" mode="base-styling">
    <xsl:if test="@fontsize">
      <xsl:value-of select="concat('font-size:',@fontsize,';')"/>
    </xsl:if>
    <xsl:if test="@width"  ><xsl:value-of select="concat('width:',@width,';')"/></xsl:if>
    <xsl:if test="@height" >
      <xsl:choose>
        <xsl:when test="@depth">
          <xsl:value-of select="concat('height:',f:adddim(@height,@depth),';')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('height:',@height,';')"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
    <xsl:if test="@depth"  >
      <xsl:value-of select="concat('vertical-align:',f:negate(@depth),';')"/>
    </xsl:if>
    <xsl:if test="@xoffset">
      <xsl:value-of select="concat('position:relative; left:',@xoffset,';')"/>
    </xsl:if>
    <xsl:if test="@yoffset">
      <xsl:value-of select="concat('position:relative; bottom:',@yoffset,';')"/>
    </xsl:if>
    <xsl:if test="@color"><xsl:value-of select="concat('color:',@color,';')"/></xsl:if>
    <xsl:if test="@backgroundcolor">
      <xsl:value-of select="concat('background-color:',@backgroundcolor,';')"/>
    </xsl:if>
    <xsl:if test="@opacity"><xsl:value-of select="concat('opacity:',@opacity,';')"/></xsl:if>
    <xsl:if test="@framecolor">
      <xsl:value-of select="'border-color: '"/>
      <xsl:value-of select="@framecolor"/>
      <xsl:value-of select="';'"/>
    </xsl:if>
    <xsl:if test="@cssstyle"><xsl:value-of select="concat(@cssstyle,';')"/></xsl:if>
  </xsl:template>

  <xsl:template name="add_transformable_attributes">
    <xsl:call-template name="add_attribute">
      <xsl:with-param name="name" select="'style'"/>
      <xsl:with-param name="value">
        <xsl:if test="@innerwidth"  >
          <xsl:value-of select="concat('width:',@innerwidth,';')"/>
        </xsl:if>
        <!-- apparently we shouldn't put the innerheigth & innerdepth into the style;
         seems to mess up the positioning? -->
        <xsl:text>transform:</xsl:text>
        <xsl:apply-templates select='.' mode="transformable-transform"/>
        <xsl:text>;</xsl:text>
        <xsl:text>-webkit-transform:</xsl:text>
        <xsl:apply-templates select='.' mode="transformable-transform"/>
        <xsl:text>;</xsl:text>
        <xsl:text>-ms-transform:</xsl:text>
        <xsl:apply-templates select='.' mode="transformable-transform"/>
        <xsl:text>;</xsl:text>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="*" mode="transformable-transform">
    <xsl:if test="@xtranslate | @ytranslate">
      <xsl:value-of select="concat('translate(',f:if(@xtranslate,@xtranslate,0),',',
                                                f:if(@ytranslate,@ytranslate,0),') ')"/>
    </xsl:if>
    <xsl:if test="@xscale | @yscale">
      <xsl:value-of select="concat('scale(',f:if(@xscale,@xscale,1),',',
                                            f:if(@yscale,@yscale,1),') ')"/>
    </xsl:if>
    <xsl:if test="@angle">
      <xsl:value-of select="concat('rotate(',f:negate(@angle),'deg) ')"/>
    </xsl:if>
  </xsl:template>

  <!-- Add an RDFa attributes from the context element to the current one.
       All of these attributes (except content) could be IRI (ie. URL),
       as well as term(s), CURIE, etc.  So, should f:url(.) be applied? 
       It either needs to be written safely enough, or a safer version applied-->
  <xsl:template match="*" mode="add_RDFa">
    <!-- perhaps we want to disallow these being spread around?
    <xsl:if test="@vocab">
      <xsl:attribute name="vocab"><xsl:value-of select="@vocab"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@prefix">
      <xsl:attribute name="prefix"><xsl:value-of select="@prefix"/></xsl:attribute>
    </xsl:if>
    -->
    <xsl:if test="@about">
      <xsl:attribute name="about"><xsl:value-of select="@about"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@resource">
      <xsl:attribute name="resource"><xsl:value-of select="@resource"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@property">
      <xsl:attribute name="property"><xsl:value-of select="@property"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@rel">
      <xsl:attribute name="rel"><xsl:value-of select="@rel"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@rel">
      <xsl:attribute name="rel"><xsl:value-of select="@rel"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@rev">
      <xsl:attribute name="rev"><xsl:value-of select="@rev"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@typeof">
      <xsl:attribute name="typeof"><xsl:value-of select="@typeof"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@datatype">
      <xsl:attribute name="datatype"><xsl:value-of select="@datatype"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@content">
      <xsl:attribute name="content"><xsl:value-of select="@content"/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <xsl:template name="add_RDFa_prefix">
    <xsl:if test='/*/@prefix'>
      <xsl:attribute name='prefix'><xsl:value-of select='/*/@prefix'/></xsl:attribute>
      <xsl:if test="$RDFA_VERSION = '1.0'">
        <xsl:attribute name="version">XHTML+RDFa 1.0</xsl:attribute>
        <xsl:call-template name="add_RDFa1.0_namespaces">
          <xsl:with-param name="prefix" select="normalize-space(/*/@prefix)"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <!-- This converts the RDFa 1.1 prefix attribute into RDFa 1.0 namespace declarations
       It "SHOULD NOT" be used -->
  <xsl:template name="add_RDFa1.0_namespaces">
    <xsl:param name="prefix"/>
    <xsl:if test="$prefix != ''">
      <!-- peal off 1st "prefix: url" pair, and add as namespace declaration. -->
      <xsl:call-template name="add_namespace">
        <xsl:with-param name="prefix" select="substring-before($prefix,':')"/>
        <xsl:with-param name="url">
          <xsl:choose>
            <xsl:when test="substring-before(substring-after($prefix,' '),' ')">
              <xsl:value-of select="substring-before(substring-after($prefix,' '),' ')"/>           
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="substring-after($prefix,' ')"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:with-param>
      </xsl:call-template>
      <!-- Recurse on any remaining pairs -->
      <xsl:call-template name="add_RDFa1.0_namespaces">
        <xsl:with-param name="prefix" select="substring-after(substring-after($prefix,' '),' ')"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- obscure trickiness to add an xmlns:prefix=url without
       introducing the namespace xmlns, extra dummy qnames with prefix, and so on.-->
  <xsl:template name="add_namespace">
    <xsl:param name="prefix"/>
    <xsl:param name="url"/>
    <xsl:variable name="dummy">
      <dummy><xsl:attribute name="{concat($prefix,':dummy')}" namespace="{$url}"/></dummy>
    </xsl:variable>
    <xsl:copy-of select="exsl:node-set($dummy)/*/namespace::*"/>
  </xsl:template>

  <!-- Add a data scheme url attribute (typically href) containing the data
       stored in @data, according to @datatype and @dataencoding -->
  <xsl:template name="add_data_attribute">
    <xsl:param name="name"/>
    <xsl:attribute name="{$name}">
      <xsl:value-of select="concat('data:',
                            f:if(@datamimetype,@datamimetype,'text/plain'),
                            f:if(@dataencoding, concat(';',@dataencoding),''),
                            ',',@data)"/>
    </xsl:attribute>
  </xsl:template>

</xsl:stylesheet>


