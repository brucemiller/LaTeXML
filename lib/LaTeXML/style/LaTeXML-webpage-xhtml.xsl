<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-webpage-xhtml.xsl                                          |
|  General purpose webpage wrapper for LaTeXML documents in xhtml     |
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
    xmlns       = "http://www.w3.org/1999/xhtml"
    xmlns:string= "http://exslt.org/strings"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    exclude-result-prefixes = "ltx f"
    extension-element-prefixes="string f">

<xsl:param name="CSS"></xsl:param>

<!--  ======================================================================
      The Page
      ====================================================================== -->

<xsl:param name="n">0</xsl:param>

<xsl:template name="head">
  <xsl:text>
  </xsl:text>
  <head><xsl:text>
    </xsl:text>
    <title><xsl:value-of select="normalize-space(*/ltx:title)"/></title><xsl:text>
    </xsl:text>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <xsl:if test="/*/ltx:navigation/ltx:ref[@class='start']"><xsl:text>
    </xsl:text>
      <link rel="start" href="{/*/ltx:navigation/ltx:ref[@class='start']/@href}"
	    title="{normalize-space(.//ltx:navigation/ltx:ref[@class='start']/@title)}"/>
    </xsl:if>
    <xsl:if test="/*/ltx:navigation/ltx:ref[@class='previous']"><xsl:text>
    </xsl:text>
      <link rel="prev" href="{/*/ltx:navigation/ltx:ref[@class='previous']/@href}"
	    title="{normalize-space(.//ltx:navigation/ltx:ref[@class='previous']/@title)}"/>
    </xsl:if>
    <xsl:if test="/*/ltx:navigation/ltx:ref[@class='next']"><xsl:text>
    </xsl:text>
      <link rel="next" href="{/*/ltx:navigation/ltx:ref[@class='next']/@href}"
	    title="{normalize-space(.//ltx:navigation/ltx:ref[@class='next']/@title)}"/>
    </xsl:if>
    <xsl:if test='$CSS'>
      <xsl:for-each select="string:split($CSS,'|')"><xsl:text>
    </xsl:text>
	<link rel='stylesheet' type="text/css" href="{text()}"/>
      </xsl:for-each>
    </xsl:if>
    <xsl:if test="//ltx:indexphrase"><xsl:text>
    </xsl:text>
       <meta name="keywords" xml:lang="en-us">
	 <xsl:attribute name="content">
	   <xsl:for-each select="//ltx:indexphrase[not(.=preceding::ltx:indexphrase)]">
	     <xsl:sort select="text()"/>
	       <xsl:if test="position() &gt; 1">, </xsl:if> 
	       <xsl:value-of select="text()"/>
	     </xsl:for-each>
          </xsl:attribute>
        </meta>
    </xsl:if>
    <!-- Should include ltx:keywords here? But, we don't know how the content is formatted!-->
    <xsl:text>
  </xsl:text>
  </head>
</xsl:template>

<xsl:template name="body">
  <xsl:text>
  </xsl:text>
  <body>
    <xsl:call-template name="navbar"/>
    <xsl:text>
    </xsl:text>
    <div class='main'>
      <xsl:call-template name="header"/>
      <xsl:text>
    </xsl:text>
      <div class='content'>
        <xsl:apply-templates/>
	<xsl:text>
        </xsl:text>
      </div>
      <xsl:call-template name="footer"/>
      <xsl:text>
      </xsl:text>
      </div>
      <xsl:text>
    </xsl:text>
  </body>
</xsl:template>

<!--  ======================================================================
      Header & Footer
      ====================================================================== -->

<xsl:template name="navbar">
  <xsl:if test="//ltx:navigation/ltx:toclist">
    <xsl:text>
    </xsl:text>
    <div class='navbar'>
      <xsl:apply-templates select="//ltx:navigation/ltx:ref[@class='start']"/>
      <xsl:apply-templates select="//ltx:navigation/ltx:toclist"/>
      <xsl:text>
      </xsl:text>
    </div>
  </xsl:if>
</xsl:template>

<xsl:template name="header">
  <xsl:if test="//ltx:navigation/ltx:ref">
    <xsl:text>
    </xsl:text>
    <div class='header'>
      <xsl:apply-templates select="//ltx:navigation/ltx:ref[@class='up']"/>
      <xsl:apply-templates select="//ltx:navigation/ltx:ref[@class='previous']"/>
      <xsl:apply-templates select="//ltx:navigation/ltx:ref[@class='next']"/>
      <xsl:text>
      </xsl:text>
    </div>
  </xsl:if>
</xsl:template>

<xsl:template name="footer">
  <xsl:if test="//ltx:date[@role='creation' or @role='conversion'][1] | //ltx:navigation/ltx:ref">
    <xsl:text>
    </xsl:text>
    <div class='footer'>
      <xsl:value-of select='//ltx:date/node()'/>
      <xsl:apply-templates select="//ltx:navigation/ltx:ref[@class='previous']"/>
      <xsl:apply-templates select="//ltx:navigation/ltx:ref[@class='next']"/>
      <xsl:text>
      </xsl:text>
    </div>
  </xsl:if>
</xsl:template>

<xsl:template match="ltx:navigation"/>

<xsl:template match="ltx:navigation/ltx:ref">
  <xsl:text>
  </xsl:text>
  <a href="{@href}" class="{f:classes(.)}" title="{@title}"><xsl:value-of select="@class"/>: <xsl:apply-templates/></a>
</xsl:template>

<xsl:template match="ltx:navigation/ltx:ref[@class='start']">
  <xsl:text>
  </xsl:text>
  <a href="{@href}" class="{f:classes(.)}" title="{@title}"><xsl:apply-templates/></a>
</xsl:template>

<!--  ======================================================================
      Tables of Contents.
      ====================================================================== -->
<!-- explictly requested TOC -->
<xsl:template match="ltx:TOC[@format='short']">
  <xsl:apply-templates mode="short"/>
</xsl:template>

<xsl:template match="ltx:TOC[@format='veryshort']">
  <xsl:apply-templates mode="veryshort"/>
</xsl:template>

<xsl:template match="ltx:TOC">
  <xsl:choose>
    <xsl:when test="@class='appendixtoc'">	     
      <xsl:text>
      </xsl:text>
      <h6>Appendices</h6>
      <xsl:apply-templates/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>
      </xsl:text>
     <h6>Contents</h6>
     <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="ltx:toclist" mode="short">
  <xsl:text>
  </xsl:text>
 <div class="shorttoc"><xsl:text>
 &#x2666; </xsl:text><xsl:apply-templates mode="short"/>
  </div>
</xsl:template>

<xsl:template match="ltx:toclist" mode="veryshort">
  <xsl:text>
  </xsl:text>
  <div class="veryshorttoc">&#x2666;<xsl:apply-templates mode="veryshort"/></div>
</xsl:template>

<xsl:template match="ltx:toclist[@tocindent]">
  <xsl:text>
  </xsl:text>
  <ul class="{concat('toc toclevel',floor((@tocindent+3) div 4))}">
    <xsl:apply-templates/>
    <xsl:text>
    </xsl:text>
  </ul>
</xsl:template>

<xsl:template match="ltx:toclist">
  <xsl:text>
  </xsl:text>
  <ul class="toc">
    <xsl:apply-templates/>
    <xsl:text>
    </xsl:text>
  </ul>
</xsl:template>

<xsl:template match="ltx:tocentry">
  <xsl:text>
  </xsl:text>
  <li><xsl:call-template name='add_id'/><xsl:apply-templates/></li>
</xsl:template>

<xsl:template match="ltx:tocentry" mode="short">
  <xsl:apply-templates/><xsl:text> &#x2666; </xsl:text>
</xsl:template>

<xsl:template match="ltx:tocentry" mode="veryshort">
  <xsl:apply-templates/>&#x2666;</xsl:template>

</xsl:stylesheet>