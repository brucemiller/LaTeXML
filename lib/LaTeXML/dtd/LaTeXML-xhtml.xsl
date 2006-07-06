<?xml version="1.0" encoding="utf-8"?>
<!--
 /=====================================================================\ 
 |  LaTeXML-xhtml.xsl                                                  |
 |  Stylesheet for converting LaTeXML documents to xhtml               |
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
  xmlns:xsl   = "http://www.w3.org/1999/XSL/Transform"
  version     = "1.0"
  xmlns:xhtml = "http://www.w3.org/1999/xhtml"
  xmlns:m     = "http://www.w3.org/1998/Math/MathML"
  xmlns:ltx   = "http://dlmf.nist.gov/LaTeXML"
  exclude-result-prefixes = "xhtml m ltx"
>

<xsl:output method="xml"
	    doctype-public = "-//W3C//DTD XHTML 1.1 plus MathML 2.0//EN"
            doctype-system = "http://www.w3c.org/TR/MathML2/dtd/xhtml-math11-f.dtd"
	    media-type='application/xhtml+xml'/>
    
  <xsl:param name="NSDECL">http://www.w3.org/1999/xhtml</xsl:param>
  <xsl:param name="EXT">.xhtml</xsl:param>
  <xsl:param name="MATHML">true</xsl:param>

  <xsl:template match="ltx:Math">
    <xsl:apply-templates select="m:math"/>
  </xsl:template>

  <!-- Some kinda confusion about namespaces here! -->
  <xsl:template match="m:math">
    <math xmlns="http://www.w3.org/1998/Math/MathML" display="{@display}">
      <xsl:apply-templates/>
    </math>
  </xsl:template>

  <xsl:template match="*[namespace-uri() = 'http://www.w3.org/1998/Math/MathML']">
    <xsl:element name="{local-name()}">
      <xsl:for-each select="@*">
        <xsl:attribute name="{name()}">
          <xsl:value-of select="."/>
        </xsl:attribute>
      </xsl:for-each>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:equation[@refnum]">
    <div class='equation'> 
      <xsl:call-template name="add_id"/>
      <math xmlns="http://www.w3.org/1998/Math/MathML" display="block">
	<mtable>
	  <mlabeledtr><mtd><mtext>(<xsl:value-of select="@refnum"/>)</mtext></mtd>
	    <mtd><xsl:apply-templates select="ltx:Math/m:math/node()"/></mtd>
	  </mlabeledtr>
	</mtable>
      </math>
    </div>
  </xsl:template>

  <xsl:template match="ltx:punct">
    <xsl:apply-templates/><xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template name="add_id">
    <xsl:choose>
      <xsl:when test="@label">
	<xsl:attribute name="id"><xsl:value-of select="@label"/></xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
	<xsl:attribute name="id"><xsl:value-of select="generate-id()"/></xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:include href="LaTeXML-base.xsl"/>

</xsl:stylesheet>
