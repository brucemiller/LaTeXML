<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-math-image.xsl                                             |
|  Convert math to images for html                                    |
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
    version   = "1.0"
    xmlns:xsl = "http://www.w3.org/1999/XSL/Transform"
    xmlns:ltx = "http://dlmf.nist.gov/LaTeXML"
    exclude-result-prefixes="ltx">

  <!-- could dump a tex form or something? -->
  <xsl:template match="ltx:Math"/>

  <xsl:template match="ltx:Math[@imagesrc]">
    <img src="{@imagesrc}" width="{@imagewidth}" height="{@imageheight}" alt="{@tex}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="math"/>
	<xsl:with-param name="extra_style">
	  <xsl:if test="@imagedepth">
	    <xsl:value-of select="concat('vertical-align:-',@imagedepth,'px')"/>
	  </xsl:if>
	</xsl:with-param>
      </xsl:call-template>
    </img>
  </xsl:template>

</xsl:stylesheet>
