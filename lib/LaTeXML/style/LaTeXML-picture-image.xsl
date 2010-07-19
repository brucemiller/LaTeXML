<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-picture-image.xsl                                          |
|  Converting pictures to images for html                             |
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

  <xsl:template match="ltx:picture"/>
  <xsl:template match="ltx:picture[@imagesrc]">
    <img src="{@imagesrc}" width="{@imagewidth}" height="{@imageheight}" alt="{@tex}"  class="{f:classes(.)}"/>
  </xsl:template>

</xsl:stylesheet>
