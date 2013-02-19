<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-picture-svg.xsl                                            |
|  Converting pictures to SVG for xhtml                               |
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
    xmlns:svg   = "http://www.w3.org/2000/svg"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:xlink = "http://www.w3.org/1999/xlink"
    extension-element-prefixes="f"
    exclude-result-prefixes = "ltx f svg">

  <xsl:param name="SVG_NAMESPACE">http://www.w3.org/2000/svg</xsl:param>
  <xsl:param name="USE_SVG">true</xsl:param>

  <!-- The namespace to use on SVG elements (typically SVG_NAMESPACE or none) -->
  <xsl:param name="svg_ns">
    <xsl:value-of select="f:if($USE_NAMESPACES,$SVG_NAMESPACE,'')"/>
  </xsl:param>

  <xsl:template match="ltx:picture">
    <xsl:choose>
      <xsl:when test="svg:svg and $USE_SVG">
	<xsl:apply-templates select="." mode="as-svg"/>
      </xsl:when>
      <xsl:when test="@imagesrc">
	<xsl:apply-templates select="." mode="as-image"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates select="." mode="as-TeX"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:picture" mode="as-image">
    <xsl:element name="img" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_style">
	  <xsl:if test="@imagedepth">
	    <xsl:value-of select="concat('vertical-align:-',@imagedepth,'px')"/>
	  </xsl:if>
	</xsl:with-param>
      </xsl:call-template>
      <xsl:attribute name="src">
	<xsl:value-of select="f:url(@imagesrc)"/>
      </xsl:attribute>
      <xsl:if test="@imagewidth">
	<xsl:attribute name="width">
	  <xsl:value-of select="@imagewidth"/>
	</xsl:attribute>
      </xsl:if>
      <xsl:if test="@imageheight">
	<xsl:attribute name="height">
	  <xsl:value-of select="@imageheight"/>
	</xsl:attribute>
      </xsl:if>
      <xsl:if test="@tex">
	<xsl:attribute name="alt">
	  <xsl:value-of select="@tex"/>
	</xsl:attribute>
      </xsl:if>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:picture" mode="as-TeX">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>	
      <xsl:value-of select="@tex"/>
    </xsl:element>
  </xsl:template>

  <!-- Top level generated svg:svg element gets id & class from ltx:picture
       If ltx:picture/svg:svg had any of those, they got lost! -->
  <xsl:template match="ltx:picture" mode="as-svg">
    <xsl:element name="svn" namespace="{$svg_ns}">
      <!-- copy id, class, style from parent ltx:picture -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <!-- but copy other svg:svg attributes -->
      <xsl:for-each select="svg:svg/@*">
	<xsl:apply-templates select="." mode="copy-attribute"/>
      </xsl:for-each>
      <xsl:apply-templates select="svg:svg/*"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:picture" mode="as-svg">
    <xsl:apply-templates select="svg:svg"/>
  </xsl:template>

  <xsl:template match="svg:*">
    <xsl:element name="{local-name()}" namespace="{$svg_ns}">
      <xsl:for-each select="@*">
	<xsl:choose>
	  <xsl:when test="local-name() = 'id'">
	    <xsl:attribute name="{f:if($USE_NAMESPACES,'xml:id','id')}">
	      <xsl:value-of select="."/>
	    </xsl:attribute>
	  </xsl:when>
	  <!-- are these the attributes to watch for in svg? (urls)-->
	  <xsl:when test="name() = 'href' or name() = 'src'">
	    <xsl:attribute name="{local-name()}">
	      <xsl:value-of select="f:url(.)"/>
	    </xsl:attribute>
	  </xsl:when>
	  <xsl:when test="name()='xlink:href' or name()='xlink:role' or name()='xlink:arcrole'">
	    <xsl:attribute name="{local-name()}"
			   namespace="{f:if($USE_NAMESPACES,namespace-uri(),'')}">
	      <xsl:value-of select="f:url(.)"/>
	    </xsl:attribute>
	  </xsl:when>
	  <xsl:when test="namespace-uri() = $SVG_NAMESPACE">
	    <xsl:attribute name="{local-name()}" namespace="{f:if($USE_NAMESPACES,namespace-uri(),'')}">
	      <xsl:value-of select="."/>
	    </xsl:attribute>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:for-each>
      <xsl:choose>
	<!-- If foreignObject in a DIFFERENT namespace, copy as foreign markup -->
        <xsl:when test="local-name()='foreignObject-xml'
                        and not(namespace-uri(child::*) = $SVG_NAMESPACE)">
	  <xsl:apply-templates mode='copy-foreign'/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:apply-templates/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- If we hit svg while copying "foreign" markup, resume as above -->
  <xsl:template match="svg:*" mode="copy-foreign">
    <xsl:apply-templates/>
  </xsl:template>

  <!-- Several xlink attributes refer to urls, so take care of url ajustment
       and also (presumably) the namespace prefix should be dropped when not using namespaces?
       Not even sure if these should just be ignored (except within svg, as above)-->
  <xsl:template match="@xlink:*" mode='copy-attribute'>
    <xsl:attribute name="{local-name()}" namespace="{f:if($USE_NAMESPACES,namespace-uri(),'')}">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="@xlink:href | @xlink:role | @xlink:arcrole" mode='copy-attribute'>
    <xsl:attribute name="{local-name()}" namespace="{f:if($USE_NAMESPACES,namespace-uri(),'')}">
      <xsl:value-of select="f:url(.)"/>
    </xsl:attribute>
  </xsl:template>

</xsl:stylesheet>
