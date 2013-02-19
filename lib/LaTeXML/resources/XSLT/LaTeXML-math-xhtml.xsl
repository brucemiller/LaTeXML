<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-math-mathml.xsl                                            |
|  copy MathML for xhtml                                              |
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
    xmlns:m     = "http://www.w3.org/1998/Math/MathML"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="f"
    exclude-result-prefixes = "ltx f">

  <xsl:param name="MathML_NAMESPACE">http://www.w3.org/1998/Math/MathML</xsl:param>

  <!-- Use MathML (if available in source) -->
  <xsl:param name="USE_MathML">true</xsl:param>
  <!-- If NOT using MathML, should we avoid using images to represent pure numbers? -->
  <xsl:param name="NO_NUMBER_IMAGES">true</xsl:param>
   
  <!-- The namespace to use on MathML elements (typically MathML_NAMESPACE or none) -->
  <xsl:param name="mml_ns">
    <xsl:value-of select="f:if($USE_NAMESPACES,$MathML_NAMESPACE,'')"/>
  </xsl:param>

  <xsl:template match="ltx:Math">
    <xsl:choose>
      <!-- Prefer MathML, if allowed -->
      <xsl:when test="m:math and $USE_MathML">
	<xsl:apply-templates select="." mode="as-MathML"/>
      </xsl:when>
      <!-- Optionally avoid using images for pure numbers -->
      <xsl:when test="$NO_NUMBER_IMAGES and ltx:XMath[count(*)=1][ltx:XMTok[1][@role='NUMBER']]">
	<xsl:value-of select="ltx:XMath/ltx:XMTok/text()"/>
      </xsl:when>
      <xsl:when test="$NO_NUMBER_IMAGES and
		      ltx:XMath[count(*)=1][ltx:XMApp[count(*)=2
		                        and ltx:XMTok[1][@meaning='minus']
					and ltx:XMTok[2][@role='NUMBER']]]">
	<xsl:value-of select="concat('&#x2212;',ltx:XMath/ltx:XMApp/ltx:XMTok[2]/text())"/>
      </xsl:when>
      <!-- Or use images for math (Ugh!)-->
      <xsl:when test="@imagesrc">
	<xsl:apply-templates select="." mode="as-image"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates select="." mode="as-TeX"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <xsl:template match="ltx:Math" mode="as-image">
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

  <xsl:template match="ltx:Math" mode="as-TeX">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>	
      <xsl:value-of select="@tex"/>
    </xsl:element>
  </xsl:template>

  <!-- Top level generated m:math element gets id & class from ltx:Math
       If the ltx:Math/m:math had any of those, they got lost! -->
  <xsl:template match="ltx:Math" mode="as-MathML">
    <xsl:element name="math" namespace="{$mml_ns}">
      <!-- copy id, class, style from PARENT ltx:Math -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <!-- but copy OTHER m:math attributes -->
      <xsl:for-each select="m:math/@*">
	<xsl:apply-templates select="." mode="copy-attribute"/>
      </xsl:for-each>
      <xsl:apply-templates select="m:math/*"/>
    </xsl:element>
  </xsl:template>

  <!-- Copy MathML, as is -->
  <xsl:template match="m:*">
    <xsl:element name="{local-name()}" namespace="{$mml_ns}">
      <xsl:for-each select="@*">
	<xsl:apply-templates select="." mode="copy-attribute"/>
      </xsl:for-each>
      <xsl:choose>
	<!-- If annotation-xml in a DIFFERENT namespace, copy as foreign markup -->
        <xsl:when test="local-name()='annotation-xml'                              
                        and not(namespace-uri(child::*) = $MathML_NAMESPACE)">
	  <xsl:apply-templates mode='copy-foreign'/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:apply-templates/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- If we hit MathML while copying "foreign" markup, resume as above -->
  <xsl:template match="m:*" mode="copy-foreign">
    <xsl:apply-templates/>
  </xsl:template>

</xsl:stylesheet>
