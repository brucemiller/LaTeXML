<?xml version="1.0" encoding="utf-8"?>
<!--
 /=====================================================================\ 
 |  LaTeXML-html.xsl                                                   |
 |  Stylesheet for converting LaTeXML documents to html                |
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
   xmlns:xsl = "http://www.w3.org/1999/XSL/Transform"
   version   = "1.0"
   xmlns:ltx = "http://dlmf.nist.gov/LaTeXML"
   exclude-result-prefixes='ltx'
   >

<xsl:output
   method = "html"
   omit-xml-declaration = 'yes'
   doctype-public = "-//W3C//DTD HTML 4.01//EN"
   doctype-system = "http://www.w3c.org/TR/html4/strict.dtd"
   media-type     = 'text/html'/>

  <xsl:param name="NSDECL"/>
  <xsl:param name="EXT">.html</xsl:param>
  <xsl:param name="MATHML">false</xsl:param>

  <!-- could dump a tex form or something? -->
  <xsl:template match="ltx:Math"/>

  <xsl:template match="ltx:Math[@imagesrc]">
    <img src="{@imagesrc}" width="{@imagewidth}" height="{@imageheight}" alt="{@tex}" class='math'/>
  </xsl:template>

  <!-- ignore (if preceded by an IMath?) -->
  <xsl:template match="ltx:punct"/>

  <xsl:template name="add_id">
    <xsl:if test="@label">
      <a name='{@label}'></a>
    </xsl:if>
  </xsl:template>

  <xsl:include href="LaTeXML-base.xsl"/>

</xsl:stylesheet>
