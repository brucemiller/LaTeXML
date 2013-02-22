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
    extension-element-prefixes="func f"
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
      <xsl:value-of select="substring($string,string-length($string) - string-length($ending))
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
       It's useful for MathML's annotation-xml, or SVG's foreignObject.
       We use local-name() & namespace to try avoid namespace prefixes.
       But note that namespaced attributes WILL still be preserved.
       INCLUDING xml:id; not sure if html5 really accepts that,
       but it doesn't really accept arbitrary annotations, anyway.

       Perhaps this should be smart about svg in mathml or vice-versa?
  -->
  <xsl:template match="*" mode='copy-foreign'>
    <xsl:element name="{local-name()}" namespace="{namespace-uri()}">
      <xsl:for-each select="@*">
	<xsl:apply-templates select="." mode="copy-attribute"/>
      </xsl:for-each>
      <xsl:apply-templates mode='copy-foreign'/>
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

  <xsl:template match="@*" mode='copy-attribute'>
    <xsl:attribute name="{local-name()}" namespace="{namespace-uri()}">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="@xml:id" mode='copy-attribute'>
    <xsl:attribute name="{f:if($USE_NAMESPACES,'xml:id','id')}">
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
       (1) define template with mode="classes", possibly calling <xsl:apply-imports/>
       (2) pass in parameter $extra_classes
  -->
  <xsl:template name="add_classes">
    <xsl:param name="extra_classes" select="''"/>
    <xsl:call-template name="add_attribute">
      <xsl:with-param name="name" select="'class'"/>
      <xsl:with-param name="value">
	<xsl:apply-templates select="." mode="classes"/>
	<xsl:if test="$extra_classes">
	  <xsl:text> </xsl:text>
	  <xsl:value-of select="$extra_classes"/>
	</xsl:if>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="*" mode="classes">
    <xsl:value-of select="concat('ltx_',local-name(.))"/>
    <xsl:if test="@class">
      <xsl:value-of select="concat(' ',@class)"/> <!--Whatever strings that were given! -->
    </xsl:if>
    <xsl:if test="@font">
      <xsl:value-of select="concat(' ',f:class-pref('ltx_font_',@font))"/>
    </xsl:if>
    <xsl:if test="@fontsize">
      <xsl:value-of select="concat(' ',f:class-pref('ltx_font_',@fontsize))"/>
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
       (1) define template with mode="styling", possibly calling <xsl:apply-imports/>
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
    <xsl:if test="@width"  ><xsl:value-of select="concat('width:',@width,';')"/></xsl:if>
    <xsl:if test="@height" ><xsl:value-of select="concat('height:',@height,';')"/></xsl:if>
    <xsl:if test="@depth"  ><xsl:value-of select="concat('vertical-align:',@depth,';')"/></xsl:if>
    <xsl:if test="@pad-width" ><xsl:value-of select="concat('height:',@pad-width,';')"/></xsl:if>
    <xsl:if test="@pad-height"><xsl:value-of select="concat('height:',@pad-height,';')"/></xsl:if>
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
    <xsl:if test="@framed='rectangle'">
      <xsl:value-of select="'border:1px solid '"/>
      <xsl:choose>
	<xsl:when test="@framecolor">
	  <xsl:value-of select="@framecolor"/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:value-of select="'black'"/>
	</xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select="';'"/>
    </xsl:if>
    <xsl:if test="@framed='underline'">
      <xsl:value-of select="'text-decoration:underline;'"/>
    </xsl:if>
    <xsl:if test="@cssstyle"><xsl:value-of select="concat(@cssstyle,';')"/></xsl:if>
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

</xsl:stylesheet>


