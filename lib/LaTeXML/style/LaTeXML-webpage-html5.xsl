<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-webpage-html5.xsl                                          |
|  General purpose webpage wrapper for LaTeXML documents in html5     |
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
    xmlns:string= "http://exslt.org/strings"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    exclude-result-prefixes = "ltx f"
    extension-element-prefixes="string f">

  <xsl:param name="CSS"></xsl:param>
  <xsl:param name="JAVASCRIPT"></xsl:param>
  <xsl:param name="ICON"></xsl:param>
  <xsl:param name="TIMESTAMP"></xsl:param>

  <!--  ======================================================================
       The Page
       ====================================================================== -->

  <xsl:param name="n">0</xsl:param>

  <xsl:template name="head">
    <xsl:text>&#x0A;</xsl:text>
    <head>
      <xsl:text>&#x0A;</xsl:text>
      <xsl:choose>
	<xsl:when test="*/ltx:title">
	  <title>
	    <xsl:apply-templates select="*/ltx:title" mode="visible-text"/>
	    <xsl:for-each select="//ltx:navigation/ltx:ref[@rel='up']"
			  > &#x2023; <xsl:value-of select="@title"/></xsl:for-each>
	  </title>
	</xsl:when>
	<!-- must have a title for validity! -->
	<xsl:otherwise>
	  <title></title>
	</xsl:otherwise>
      </xsl:choose>
      <xsl:text>&#x0A;</xsl:text>
      <xsl:call-template name="LaTeXML_identifier"/>
      <xsl:call-template name="metatype"/>
      <!--
      <xsl:if test="/*/ltx:navigation/ltx:ref[@rel='start']">
	<xsl:text>&#x0A;</xsl:text>
	<link rel="start" href="{/*/ltx:navigation/ltx:ref[@rel='start']/@href}"
	      title="{normalize-space(.//ltx:navigation/ltx:ref[@rel='start']/@title)}"/>
      </xsl:if>
      <xsl:if test="/*/ltx:navigation/ltx:ref[@rel='prev']">
	<xsl:text>&#x0A;</xsl:text>
	<link rel="prev" href="{/*/ltx:navigation/ltx:ref[@rel='prev']/@href}"
	      title="{normalize-space(.//ltx:navigation/ltx:ref[@rel='prev']/@title)}"/>
      </xsl:if>
      <xsl:if test="/*/ltx:navigation/ltx:ref[@rel='next']">
	<xsl:text>&#x0A;</xsl:text>
	<link rel="next" href="{/*/ltx:navigation/ltx:ref[@rel='next']/@href}"
	      title="{normalize-space(.//ltx:navigation/ltx:ref[@rel='next']/@title)}"/>
      </xsl:if>
      -->
      <xsl:apply-templates select="/*/ltx:navigation/ltx:ref[@href]" mode="inhead"/>
      <xsl:apply-templates select="/*/ltx:creator[@href]" mode="inhead"/>
      <xsl:if test='$ICON'>
	<link rel="shortcut icon" href="{$ICON}" type="image/x-icon"/>
      </xsl:if>
      <xsl:if test='$CSS'>
	<xsl:for-each select="string:split($CSS,'|')">
	  <xsl:text>&#x0A;</xsl:text>
	  <link rel='stylesheet' type="text/css" href="{text()}"/>
	</xsl:for-each>
      </xsl:if>
      <xsl:if test='$JAVASCRIPT'>
	<xsl:for-each select="string:split($JAVASCRIPT,'|')">
	  <xsl:text>&#x0A;</xsl:text>
	  <script src="{text()}" type="text/javascript"/>
	</xsl:for-each>
      </xsl:if>
      <xsl:if test="//ltx:indexphrase">
	<xsl:text>&#x0A;</xsl:text>
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
      <xsl:text>&#x0A;</xsl:text>
    </head>
  </xsl:template>

  <xsl:template match="ltx:navigation/ltx:ref[@rel]" mode="inhead">
    <xsl:text>&#x0A;</xsl:text>
    <link rel="{@rel}" href="{@href}" title="{normalize-space(@title)}"/>
  </xsl:template>
  <xsl:template match="ltx:navigation/ltx:ref[@rev]" mode="inhead">
    <xsl:text>&#x0A;</xsl:text>
    <link rev="{@rev}" href="{@href}" title="{normalize-space(@title)}"/>
  </xsl:template>

  <xsl:template match="text()" mode="visible-text"><xsl:value-of select="."/></xsl:template>
  <xsl:template match="*" mode="visible-text"><xsl:apply-templates mode="visible-text"/></xsl:template>
  <xsl:template match="ltx:indexphrase" mode="visible-text"/>

  <xsl:template name="body">
    <xsl:text>&#x0A;</xsl:text>
    <body>
      <xsl:call-template name="navbar"/>
      <xsl:text>&#x0A;</xsl:text>
      <div class='main'>
	<xsl:call-template name="header"/>
	<xsl:text>&#x0A;</xsl:text>
	<div class='content'>
	  <xsl:apply-templates/>
	  <xsl:text>&#x0A;</xsl:text>
	</div>
	<xsl:call-template name="footer"/>
	<xsl:text>&#x0A;</xsl:text>
      </div>
      <xsl:text>&#x0A;</xsl:text>
    </body>
  </xsl:template>

  <!--  ======================================================================
       Header & Footer
       ====================================================================== -->

  <xsl:template name="navbar">
    <xsl:if test="//ltx:navigation/ltx:TOC">
      <xsl:text>&#x0A;</xsl:text>
      <nav class='navbar'>
	<xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='start']"/>
	<xsl:apply-templates select="//ltx:navigation/ltx:TOC"/>
	<xsl:text>&#x0A;</xsl:text>
      </nav>
    </xsl:if>
  </xsl:template>

  <xsl:template name="header">
    <xsl:if test="//ltx:navigation/ltx:ref">
      <xsl:text>&#x0A;</xsl:text>
      <header class='header'>
	<xsl:text>&#x0A;</xsl:text>
	<div>
	  <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='up']"/>
	  <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='prev']"/>
	  <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='next']"/>
	  <xsl:text>&#x0A;</xsl:text>
	</div>
	<xsl:text>&#x0A;</xsl:text>
      </header>
    </xsl:if>
  </xsl:template>

  <xsl:template name="footer">
    <xsl:if test="//ltx:date[@role='creation' or @role='conversion'][1] | //ltx:navigation/ltx:ref">
      <xsl:text>&#x0A;</xsl:text>
      <footer class='footer'>
	<xsl:text>&#x0A;</xsl:text>
	<div>
	  <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='prev']"/>
	  <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='bibliography']"/>
	  <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='index']"/>
	  <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='glossary']"/>
	  <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='next']"/>
	  <xsl:text>&#x0A;</xsl:text>
	</div>
	<xsl:call-template name="LaTeXML-logo"/>
	<xsl:text>&#x0A;</xsl:text>
      </footer>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:navigation"/>

  <xsl:template name="LaTeXML-logo">
    <div class='LaTeXML-logo'>Generated
    <xsl:if test="$TIMESTAMP"> on <xsl:value-of select="$TIMESTAMP"/></xsl:if>
    by <a href="http://dlmf.nist.gov/LaTeXML/">LaTeXML <img src="{f:LaTeXML-icon()}" alt="[LOGO]"/></a></div>
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
    <xsl:if test="ltx:toclist/descendant::ltx:tocentry">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:if test="@name"><h6><xsl:apply-templates select="@name"/><xsl:text>:</xsl:text></h6></xsl:if>
      <xsl:apply-templates/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:toclist" mode="short">
    <xsl:text>&#x0A;</xsl:text>
    <div class="shorttoc"><xsl:text>
      &#x2666; </xsl:text><xsl:apply-templates mode="short"/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:toclist" mode="veryshort">
    <xsl:text>&#x0A;</xsl:text>
    <div class="veryshorttoc">&#x2666;<xsl:apply-templates mode="veryshort"/></div>
  </xsl:template>

  <xsl:template match="ltx:toclist[@tocindent]">
    <xsl:text>&#x0A;</xsl:text>
    <ul class="{concat('toc toclevel',floor((@tocindent+3) div 4))}">
      <xsl:apply-templates/>
      <xsl:text>&#x0A;</xsl:text>
    </ul>
  </xsl:template>

  <xsl:template match="ltx:toclist">
    <xsl:text>&#x0A;</xsl:text>
    <ul class="toc">
      <xsl:apply-templates/>
      <xsl:text>&#x0A;</xsl:text>
    </ul>
  </xsl:template>

  <xsl:template match="ltx:tocentry">
    <xsl:text>&#x0A;</xsl:text>
    <li>
      <xsl:call-template name='add_id'/>
      <xsl:call-template name='add_attributes'/>
      <xsl:apply-templates/>
    </li>
  </xsl:template>

  <xsl:template match="ltx:tocentry" mode="short">
    <xsl:apply-templates/><xsl:text> &#x2666; </xsl:text>
  </xsl:template>

  <xsl:template match="ltx:tocentry" mode="veryshort">
  <xsl:apply-templates/>&#x2666;</xsl:template>

</xsl:stylesheet>
