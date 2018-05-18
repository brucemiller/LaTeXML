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
    xmlns:string= "http://exslt.org/strings"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:m     = "http://www.w3.org/1998/Math/MathML"
    exclude-result-prefixes = "ltx f"
    extension-element-prefixes="string f">

  <!-- Include these "|" separated CSS files -->
  <xsl:param name="CSS"></xsl:param>
  <!-- Include these "|" separated Javascript files -->
  <xsl:param name="JAVASCRIPT"></xsl:param>
  <!-- Use this image file as icon -->
  <xsl:param name="ICON"></xsl:param>
  <!-- Use this string as the created date/time timestamp -->
  <xsl:param name="TIMESTAMP"></xsl:param>

  <xsl:param name="HEAD_TITLE_PREFIX"></xsl:param>
  <xsl:param name="HEAD_TITLE_SHOW_CONTEXT">true</xsl:param>

  <!-- We don't really anticipate page structure appearing in inline contexts,
       so we pretty much ignore the $context switches.
       See the CONTEXT discussion in LaTeXML-common -->

  <!--  ======================================================================
       The Page
       ====================================================================== -->

  <!-- This schematic gives an indication of the default page structure.
       You can, of course, use CSS to lay it out differently!
       <html>
         <head>...</head>
         <body>
           <div class="ltx_page_navbar>...</div>
           <div class="ltx_page_main">
             <div class="ltx_page_header">
               header navigation
             </div>
             <div class="ltx_page_content">
               Your Document Here!
               ...
             </div>
             <div class="ltx_page_footer">
               footer navigation
               LaTeXML logo
             </div>
           </div>
         </body>
       </html>
  -->
  <!-- This version generates MathML & SVG with an xmlns namespace declaration 
       on EACH math/svg node;
       If you want to declare and use namespace prefixes (m & svg, resp), add this here
       xmlns:m   = "http://www.w3.org/1998/Math/MathML"
       xmlns:svg = "http://www.w3.org/2000/svg"
       and change local-name() to name() in LaTeXML-math-mathml & LaTeXML-picture-svg.
       NOTE: Can I make a template to add namespace prefix declarations here?
       Then $USE_NAMESPACES .. ? Do the experiment!!
  -->

  <xsl:template match="/" mode="doctype"/>

  <xsl:template match="/">
    <xsl:apply-templates select="." mode="doctype"/>
    <xsl:element name="html" namespace="{$html_ns}">
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:call-template name="add_RDFa_prefix"/>
      <xsl:if test="*/@xml:lang">
        <xsl:apply-templates select="*/@xml:lang" mode="copy-attribute"/>
      </xsl:if>
      <xsl:apply-templates select="." mode="head"/>
      <xsl:apply-templates select="." mode="body"/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <!--  ======================================================================
       The <head>
       ====================================================================== -->

  <xsl:template match="/" mode="head">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="head" namespace="{$html_ns}">
      <xsl:apply-templates select="." mode="head-begin"/>
      <xsl:apply-templates select="." mode="head-title"/>
      <xsl:apply-templates select="." mode="head-generator-identifier"/>
      <xsl:apply-templates select="." mode="head-content-type"/>
      <xsl:apply-templates select="." mode="head-icon"/>
      <xsl:apply-templates select="." mode="head-resources"/>
      <xsl:apply-templates select="." mode="head-css"/>
      <xsl:apply-templates select="." mode="head-javascript"/>
      <xsl:apply-templates select="." mode="head-links"/>
      <xsl:apply-templates select="." mode="head-keywords"/>
      <xsl:apply-templates select="." mode="head-end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="/" mode="head-begin"/>
  <xsl:template match="/" mode="head-end"/>

  <!-- Generate an appropriate title element (for the head) -->
  <xsl:template match="/" mode="head-title">
    <xsl:text>&#x0A;</xsl:text>
    <!-- must have a title, even empty, for validity! -->
    <xsl:element name="title" namespace="{$html_ns}">
      <xsl:value-of select="$HEAD_TITLE_PREFIX"/>
      <xsl:choose>
        <xsl:when test="descendant::ltx:title | descendant::ltx:caption">
          <xsl:if test="$HEAD_TITLE_PREFIX">
            <xsl:text>: </xsl:text>
          </xsl:if>
          <xsl:choose>
            <xsl:when test="descendant::ltx:title">
              <xsl:apply-templates select="descendant::ltx:title[position()=1]"
                                   mode="head-toctitle"/>
            </xsl:when>
            <xsl:when test="descendant::ltx:caption">
              <xsl:apply-templates select="descendant::ltx:caption[position()=1]"
                                   mode="head-toctitle"/>
            </xsl:when>
          </xsl:choose>
          <xsl:if test="$HEAD_TITLE_SHOW_CONTEXT">
            <xsl:for-each select="//ltx:navigation/ltx:ref[@rel='up']">
              <xsl:text>&#x2023; </xsl:text>
              <xsl:value-of select="@title"/>
            </xsl:for-each>
          </xsl:if>
        </xsl:when>
        <!-- Must have _something_ for validity? -->
        <xsl:when test="not($HEAD_TITLE_PREFIX)">
          <xsl:text>Untitled Document</xsl:text>
        </xsl:when>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- Use the sibling toctitle|toccaption instead of title|caption, if any -->
  <xsl:template match="*" mode="head-toctitle">
    <xsl:choose>
      <xsl:when test="following-sibling::ltx:toctitle | following-sibling::ltx:toccaption
                      | preceding-sibling::ltx:toctitle | preceding-sibling::ltx:toccaption">
        <xsl:apply-templates select="following-sibling::ltx:toctitle
                                     | following-sibling::ltx:toccaption
                                     | preceding-sibling::ltx:toctitle
                                     | preceding-sibling::ltx:toccaption"
                             mode="visible-text"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="visible-text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="text()" mode="visible-text">
    <!-- normalize space, but preserve leading & trailing -->
    <xsl:if test="starts-with(translate(.,'&#x0a;',' '),' ')"><xsl:text> </xsl:text></xsl:if>
    <xsl:value-of select="normalize-space(.)"/>
    <xsl:if test="substring(translate(.,'&#x0a;',' '),string-length(.)) = ' '"><xsl:text> </xsl:text></xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="visible-text">
    <xsl:apply-templates mode="visible-text"/>
  </xsl:template>
  <xsl:template match="ltx:indexphrase" mode="visible-text"/>

  <xsl:template match="ltx:tag" mode="visible-text">
    <xsl:if test="@open"><xsl:value-of select="@open"/></xsl:if>
    <xsl:apply-templates mode="visible-text"/>
    <xsl:if test="@close"><xsl:value-of select="@close"/></xsl:if>
  </xsl:template>

  <!--  ======================================================================
       extracting visible plain (unicode) text from math markup -->
  <xsl:template match="ltx:Math" mode="visible-text">
    <xsl:choose>
      <xsl:when test="m:math"><xsl:apply-templates select="m:math" mode="visible-text"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="@tex"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="m:math" mode="visible-text">
    <xsl:apply-templates mode="visible-text"/>
  </xsl:template>

  <xsl:template match="m:semantics" mode="visible-text">
    <xsl:apply-templates select="*[1]" mode="visible-text"/>
  </xsl:template>

  <xsl:template match="*" mode="visible-nested">
    <xsl:text>{</xsl:text>
    <xsl:apply-templates select="." mode="visible-text"/>
    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template match="m:mo | m:mi | m:mn" mode="visible-nested">
    <xsl:apply-templates select="." mode="visible-text"/>
  </xsl:template>

  <xsl:template match="*" mode="visible-script">
    <xsl:param name="op"/>
    <xsl:value-of select="$op"/>
    <xsl:apply-templates select="." mode="visible-nested"/>
  </xsl:template>

  <xsl:template match="m:none" mode="visible-script"/>

  <xsl:template match="m:mo[contains(text(),'&#x2032;')]" mode="visible-script">
    <xsl:value-of select="text()"/>
  </xsl:template>

  <!-- Combining accents -->
  <xsl:template match="m:mo[text()='&#x60;']" mode="visible-script">
    <xsl:text>&#x0300;</xsl:text>
  </xsl:template>
  <xsl:template match="m:mo[text()='&#xB4;']" mode="visible-script">
    <xsl:text>&#x0301;</xsl:text>
  </xsl:template>
  <xsl:template match="m:mo[text()='&#x5E;']" mode="visible-script">
    <xsl:text>&#x0302;</xsl:text>
  </xsl:template>
  <xsl:template match="m:mo[text()='~']" mode="visible-script">
    <xsl:text>&#x0303;</xsl:text>
  </xsl:template>
  <xsl:template match="m:mo[text()='&#xAF;']" mode="visible-script">
    <xsl:text>&#x0304;</xsl:text>
  </xsl:template>
  <xsl:template match="m:mo[text()='&#x02D8;']" mode="visible-script">
    <xsl:text>&#x0306;</xsl:text>
  </xsl:template>
  <xsl:template match="m:mo[text()='&#x02D9;']" mode="visible-script">
    <xsl:text>&#x0307;</xsl:text>
  </xsl:template>
  <xsl:template match="m:mo[text()='o']" mode="visible-script">
    <xsl:text>&#x030A;</xsl:text>
  </xsl:template>
  <xsl:template match="m:mo[text()='&#x02DD;']" mode="visible-script">
    <xsl:text>&#x030B;</xsl:text>
  </xsl:template>
  <xsl:template match="m:mo[text()='&#x02C7;']" mode="visible-script">
    <xsl:text>&#x030C;</xsl:text>
  </xsl:template>

  <xsl:template match="m:msub | m:munder" mode="visible-text">
    <xsl:apply-templates select="*[1]" mode="visible-text"/>
    <xsl:apply-templates select="*[2]" mode="visible-script">
      <xsl:with-param name="op" select="'_'"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="m:msup | m:mover" mode="visible-text">
    <xsl:apply-templates select="*[1]" mode="visible-text"/>
    <xsl:apply-templates select="*[2]" mode="visible-script">
      <xsl:with-param name="op" select="'^'"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="m:msubsup | m:munderover" mode="visible-text">
    <xsl:apply-templates select="*[1]" mode="visible-text"/>
    <xsl:apply-templates select="*[2]" mode="visible-script">
      <xsl:with-param name="op" select="'_'"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="*[3]" mode="visible-script">
      <xsl:with-param name="op" select="'^'"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="m:mmultiscripts" mode="visible-text">
    <xsl:choose>
      <xsl:when test="m:mprescripts">
        <xsl:call-template name="multiscripts_pre">
          <xsl:with-param name="m" select="count(m:mprescripts/preceding-sibling::*)+1"/>
          <xsl:with-param name="n" select="count(*)"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="*[1]" mode="visible-nested"/>
        <xsl:call-template name="multiscripts">
          <xsl:with-param name="i" select="2"/>
          <xsl:with-param name="n" select="count(*)"/>
          <xsl:with-param name="op" select="'_'"/>
          <xsl:with-param name="other" select="'^'"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="multiscripts_pre">
    <xsl:param name="m"/>
    <xsl:param name="n"/>
    <xsl:text>{}</xsl:text>
    <xsl:call-template name="multiscripts">
      <xsl:with-param name="i" select="2"/>
      <xsl:with-param name="n" select="$m - 1"/>
      <xsl:with-param name="op" select="'_'"/>
      <xsl:with-param name="other" select="'^'"/>
    </xsl:call-template>
    <xsl:apply-templates select="*[1]" mode="visible-text"/>
    <xsl:call-template name="multiscripts">
      <xsl:with-param name="i" select="$m + 1"/>
      <xsl:with-param name="n" select="$n"/>
      <xsl:with-param name="op" select="'_'"/>
      <xsl:with-param name="other" select="'^'"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="multiscripts">
    <xsl:param name="i"/>
    <xsl:param name="n"/>
    <xsl:param name="op"/>
    <xsl:param name="other"/>
    <xsl:if test="$i &lt;= $n">
      <xsl:apply-templates select="*[$i]" mode="visible-script">
        <xsl:with-param name="op" select="$op"/>
      </xsl:apply-templates>
      <xsl:call-template name="multiscripts">
        <xsl:with-param name="i" select="$i+1"/>
        <xsl:with-param name="n" select="$n"/>
        <xsl:with-param name="op" select="$other"/>
        <xsl:with-param name="other" select="$op"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="m:mfrac" mode="visible-text">
    <xsl:apply-templates select="*[1]" mode="visible-nested"/>
    <xsl:text>/</xsl:text>
    <xsl:apply-templates select="*[2]" mode="visible-nested"/>
  </xsl:template>

  <xsl:template match="m:mphantom" mode="visible-text"/>
  <xsl:template match="m:mspace" mode="visible-text">
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="m:mfenced"  mode="visible-text">
    <xsl:value-of select="@open | '('"/>
    <xsl:apply-templates mode="visible-text-punctuated"/>
    <xsl:value-of select="@close | ')'"/>  
  </xsl:template>

  <!-- NO, I'm not going to try to decipher @separators -->
  <xsl:template match="*"  mode="visible-text-punctuated">
    <xsl:apply-templates mode="visible-text"/>    
    <xsl:if test="./following-sibling::*">
      <xsl:text>,</xsl:text>
    </xsl:if>
  </xsl:template>
    
  <xsl:template match="m:mtable"  mode="visible-text">
    <xsl:text>[</xsl:text>
    <xsl:apply-templates mode="visible-text"/>    
    <xsl:text>]</xsl:text>
  </xsl:template>

  <xsl:template match="m:mtr"  mode="visible-text">
    <xsl:text>[</xsl:text>
    <xsl:apply-templates mode="visible-text"/>    
    <xsl:text>]</xsl:text>
  </xsl:template>

  <xsl:template match="m:mtd"  mode="visible-text">
    <xsl:apply-templates mode="visible-text"/>    
    <xsl:if test="./following-sibling::m:mtd">
      <xsl:text>,</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="m:menclose"  mode="visible-text">
    <xsl:value-of select="@notation"/>
    <xsl:text>(</xsl:text>
    <xsl:apply-templates mode="visible-text"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="m:msqrt" mode="visible-text">
    <xsl:text>sqrt(</xsl:text>
    <xsl:apply-templates mode="visible-text"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="m:mroot" mode="visible-text">
    <xsl:text>root(</xsl:text>
    <xsl:apply-templates select="*[1]" mode="visible-text"/>
    <xsl:text>,</xsl:text>
    <xsl:apply-templates select="*[2]" mode="visible-text"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="m:merror" mode="visible-text">
    <xsl:text>ERROR(</xsl:text>
    <xsl:apply-templates mode="visible-text"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <!--  ====================================================================== -->

  <!-- Generate an identifier for the "generator", ie. program that created these files-->
  <xsl:template match="/" mode="head-generator-identifier">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:call-template name="LaTeXML_identifier"/>
  </xsl:template>

  <!-- Generate a meta indicating the content-type -->
  <xsl:template match="/" mode="head-content-type">
    <xsl:text>&#x0A;</xsl:text>
    <!-- Heuristically assume if we're using a namespace, we're xhtml -->
    <xsl:element name="meta" namespace="{$html_ns}">
      <xsl:attribute name="http-equiv">Content-Type</xsl:attribute>
      <xsl:attribute name="content">
        <xsl:value-of select="f:if($USE_NAMESPACES,'application/xhtml+xml','text/html')"/>
        <xsl:text>; charset=UTF-8</xsl:text>
      </xsl:attribute>
    </xsl:element>
  </xsl:template>

  <!-- Generate an "icon" link for the head -->
  <xsl:template match="/" mode="head-icon">
    <xsl:if test='$ICON'>
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="link" namespace="{$html_ns}">
        <xsl:attribute name="rel">shortcut icon</xsl:attribute>
        <xsl:attribute name="href"><xsl:value-of select="f:url($ICON)"/></xsl:attribute>
        <xsl:attribute name="type">
          <xsl:choose>          <!--Ugh-->
            <xsl:when test="f:ends-with($ICON,'.png')">image/png</xsl:when>
            <xsl:otherwise>image/x-icon</xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <!-- Generate head entries based on resources.
       These should generally come before the CSS, JAVASCRIPT parameters are processed
       so that the latter will override the former. -->
  <xsl:template match="/" mode="head-resources">
    <xsl:apply-templates select="//ltx:resource[@type='text/css']
                                 | //ltx:resource[@type='text/javascript']" mode="inhead"/>
  </xsl:template>

  <!-- By default, these disappear -->
  <xsl:template match="ltx:resource"/>

  <xsl:template match="ltx:resource[@type='text/css' and @src]" mode="inhead">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="link" namespace="{$html_ns}">
      <xsl:attribute name="rel">stylesheet</xsl:attribute>
      <xsl:attribute name="href"><xsl:value-of select="f:url(@src)"/></xsl:attribute>
      <xsl:attribute name="type"><xsl:value-of select="@type"/></xsl:attribute>
      <xsl:if test="@media">
        <xsl:attribute name="media"><xsl:value-of select="@media"/></xsl:attribute>
      </xsl:if>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:resource[@type='text/css' and text()]" mode="inhead">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="style" namespace="{$html_ns}">
      <xsl:attribute name="type"><xsl:value-of select="@type"/></xsl:attribute>
      <xsl:if test="@media">
        <xsl:attribute name="media"><xsl:value-of select="@media"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="text()"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:resource[@type='text/javascript' and @src]" mode="inhead">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="script" namespace="{$html_ns}">
      <xsl:attribute name="src"><xsl:value-of select="f:url(@src)"/></xsl:attribute>
      <xsl:attribute name="type"><xsl:value-of select="@type"/></xsl:attribute>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:resource[@type='text/javascript' and text()]" mode="inhead">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="script" namespace="{$html_ns}">
      <xsl:attribute name="type"><xsl:value-of select="@type"/></xsl:attribute>
      <xsl:apply-templates select="text()"/>
    </xsl:element>
  </xsl:template>

  <!-- Generate CSS line & style entries for the head.
       NOTE: Make allowance for media=print (or other media!)-->
  <xsl:template match="/" mode="head-css">
    <xsl:if test='$CSS'>
      <xsl:for-each select="string:split($CSS,'|')">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="link" namespace="{$html_ns}">
          <xsl:attribute name="rel">stylesheet</xsl:attribute>
          <xsl:attribute name="href"><xsl:value-of select="f:url(text())"/></xsl:attribute>
          <xsl:attribute name="type">text/css</xsl:attribute>
        </xsl:element>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <!-- Generate javascript script entries for the head -->
  <xsl:template match="/" mode="head-javascript">
    <xsl:if test='$JAVASCRIPT'>
      <xsl:for-each select="string:split($JAVASCRIPT,'|')">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="script" namespace="{$html_ns}">
          <xsl:attribute name="src"><xsl:value-of select="f:url(text())"/></xsl:attribute>
          <xsl:attribute name="type">text/javascript</xsl:attribute>
        </xsl:element>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <!-- Generate a set of links to other related documents -->
  <xsl:template match="/" mode="head-links">
    <xsl:apply-templates select="/*/ltx:navigation/ltx:ref[@href]" mode="inhead"/>
    <xsl:apply-templates select="/*/ltx:creator[ltx:personname/@href or ltx:contact/@href]" mode="inhead"/>
  </xsl:template>

  <xsl:template match="ltx:navigation/ltx:ref[@rel]" mode="inhead">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="link" namespace="{$html_ns}">
      <xsl:attribute name="rel"><xsl:value-of select="@rel"/></xsl:attribute>
      <xsl:attribute name="href"><xsl:value-of select="f:url(@href)"/></xsl:attribute>
      <xsl:attribute name="title"><xsl:value-of select="normalize-space(@title)"/></xsl:attribute>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:navigation/ltx:ref[@rev]" mode="inhead">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="link" namespace="{$html_ns}">
      <xsl:attribute name="rev"><xsl:value-of select="@rev"/></xsl:attribute>
      <xsl:attribute name="href"><xsl:value-of select="f:url(@href)"/></xsl:attribute>
      <xsl:attribute name="title"><xsl:value-of select="normalize-space(@title)"/></xsl:attribute>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:creator[@role='author'][ltx:personname[@href] or ltx:contact[@href]]" mode="inhead">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="link" namespace="{$html_ns}">
      <xsl:attribute name="rel"><xsl:value-of select='@role'/></xsl:attribute>
      <xsl:attribute name="href">
        <xsl:choose>
          <xsl:when test="ltx:personname/@href">
            <xsl:value-of select="f:url(ltx:personname/@href)"/>
          </xsl:when>
          <xsl:when test="ltx:contact/@href">
            <xsl:value-of select="f:url(ltx:contact/@href)"/>
          </xsl:when>
        </xsl:choose>
      </xsl:attribute>
      <xsl:attribute name="title">
        <xsl:value-of select="normalize-space(ltx:personname/text())"/>
      </xsl:attribute>
    </xsl:element>
  </xsl:template>

  <!-- Generate a keywords meta entry for the head; typically from indexphrase's or keywords-->
  <xsl:template match="/" mode="head-keywords">
    <xsl:if test="//ltx:indexphrase | //ltx:keywords">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="meta" namespace="{$html_ns}">
        <xsl:attribute name="name">keywords</xsl:attribute>
        <xsl:attribute name="{f:if($USE_NAMESPACES,'xml:lang','lang')}">
          <xsl:value-of select="f:if(*/@xml:lang,*/@xml:lang, 'en')"/>
        </xsl:attribute>
        <xsl:attribute name="content">
          <xsl:value-of select="f:subst(//ltx:keywords/text(),',',', ')"/>
          <xsl:if test="//ltx:indexphrase and //ltx:keywords">
            <xsl:text>, </xsl:text>
          </xsl:if>
          <xsl:for-each select="//ltx:indexphrase[not(.=preceding::ltx:indexphrase)]">
            <xsl:sort select="text()"/>
            <xsl:if test="position() &gt; 1">, </xsl:if> 
            <xsl:value-of select="text()"/>
          </xsl:for-each>
        </xsl:attribute>
      </xsl:element>
    </xsl:if>
    <!-- Should include ltx:keywords here? But, we don't know how the content is formatted!-->
  </xsl:template>

  <!--  ======================================================================
       The <body>
       ====================================================================== -->

  <xsl:template match="/" mode="body">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="body" namespace="{$html_ns}">
      <xsl:apply-templates select="." mode="body-begin"/>
      <xsl:apply-templates select="." mode="navbar"/>
      <xsl:apply-templates select="." mode="body-main"/>
      <xsl:apply-templates select="." mode="body-end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="/" mode="body-begin"/>
  <xsl:template match="/" mode="body-end"/>

  <xsl:template match="/" mode="body-main">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:attribute name="class">ltx_page_main</xsl:attribute>
      <xsl:apply-templates select="." mode="body-main-begin"/>
      <xsl:apply-templates select="." mode="header"/>
      <xsl:apply-templates select="." mode="body-content"/>
      <xsl:apply-templates select="." mode="footer"/>
      <xsl:apply-templates select="." mode="body-main-end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="/" mode="body-main-begin"/>
  <xsl:template match="/" mode="body-main-end"/>

  <xsl:template match="/" mode="body-content">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:attribute name="class">ltx_page_content</xsl:attribute>
      <xsl:apply-templates select="." mode="body-content-begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="body-content-end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="/" mode="body-content-begin"/>
  <xsl:template match="/" mode="body-content-end"/>

  <!--  ======================================================================
       Header & Footer
       ====================================================================== -->
  <!-- NOTE: Hmm...better would have named these body-navbar, body-header, body-footer....-->

  <xsl:template match="/" mode="navbar">
    <xsl:choose>
      <xsl:when test="//ltx:navigation/ltx:inline-para[@class='ltx_page_navbar']">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="{f:if($USE_HTML5,'nav','div')}" namespace="{$html_ns}">
          <xsl:attribute name="class">ltx_page_navbar</xsl:attribute>
          <xsl:apply-templates select="//ltx:navigation/ltx:inline-para[@class='ltx_page_navbar']/*"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="//ltx:navigation/ltx:TOC">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="{f:if($USE_HTML5,'nav','div')}" namespace="{$html_ns}">
          <xsl:attribute name="class">ltx_page_navbar</xsl:attribute>
          <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='start']"/>
          <xsl:apply-templates select="//ltx:navigation/ltx:TOC"/>
          <xsl:text>&#x0A;</xsl:text>
        </xsl:element>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- header/footer done in pieces so they're more easily customized:
       Define your own, and you can still call header-navigation/footer-navigation if you want.
       The test avoids an empty header/footer in default cases. -->
  <!-- NOTE: I'm not so sure that html5's header & footer really are meant to be used
       purely as navigational page header and footer-->
  <xsl:template match="/" mode="header">
    <xsl:choose>
      <xsl:when test="//ltx:navigation/ltx:inline-para[@class='ltx_page_header']">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="{f:if($USE_HTML5,'header','div')}" namespace="{$html_ns}">
          <xsl:attribute name="class">ltx_page_header</xsl:attribute>
          <xsl:apply-templates select="//ltx:navigation/ltx:inline-para[@class='ltx_page_header']/*"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="//ltx:navigation/ltx:ref">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="{f:if($USE_HTML5,'header','div')}" namespace="{$html_ns}">
          <xsl:attribute name="class">ltx_page_header</xsl:attribute>
          <xsl:apply-templates select="." mode="header-navigation"/>
        </xsl:element>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/" mode="footer">
    <xsl:choose>
      <xsl:when test="//ltx:navigation/ltx:inline-para[@class='ltx_page_footer']">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="{f:if($USE_HTML5,'footer','div')}" namespace="{$html_ns}">
          <xsl:attribute name="class">ltx_page_footer</xsl:attribute>
          <xsl:apply-templates select="//ltx:navigation/ltx:inline-para[@class='ltx_page_footer']/*"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <!-- no test, since we'll default at least with logo -->
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="{f:if($USE_HTML5,'footer','div')}" namespace="{$html_ns}">
          <xsl:attribute name="class">ltx_page_footer</xsl:attribute>
          <xsl:apply-templates select="." mode="footer-navigation"/>
          <xsl:apply-templates select="." mode="footer-generator-identifier"/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Generate a footer line identifying the "generator" (if desired)-->
  <xsl:template match="/" mode="footer-generator-identifier">
    <xsl:call-template name="LaTeXML-logo"/>
  </xsl:template>

  <xsl:template match="/" mode="header-navigation">
    <xsl:if test="//ltx:navigation/ltx:ref">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="div" namespace="{$html_ns}">
        <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='up']"/>
        <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='prev']"/>
        <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='next']"/>
        <xsl:text>&#x0A;</xsl:text>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="/" mode="footer-navigation">
    <xsl:if test="//ltx:navigation/ltx:ref">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="div" namespace="{$html_ns}">
        <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='prev']"/>
        <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='bibliography']"/>
        <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='index']"/>
        <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='glossary']"/>
        <xsl:apply-templates select="//ltx:navigation/ltx:ref[@rel='next']"/>
        <xsl:text>&#x0A;</xsl:text>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:navigation"/>

  <xsl:template name="LaTeXML-logo">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:attribute name="class">ltx_page_logo</xsl:attribute>
      <xsl:text>Generated </xsl:text>
      <xsl:if test="$TIMESTAMP"> on <xsl:value-of select="$TIMESTAMP"/></xsl:if>
      <xsl:text> by </xsl:text>
      <xsl:element name="a" namespace="{$html_ns}">
        <xsl:attribute name="href">http://dlmf.nist.gov/LaTeXML/</xsl:attribute>
        <xsl:text>LaTeXML </xsl:text>
        <xsl:element name="img" namespace="{$html_ns}">
          <xsl:attribute name="src">data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAOCAYAAAD5YeaVAAAAAXNSR0IArs4c6QAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB9wKExQZLWTEaOUAAAAddEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIFRoZSBHSU1Q72QlbgAAAdpJREFUKM9tkL+L2nAARz9fPZNCKFapUn8kyI0e4iRHSR1Kb8ng0lJw6FYHFwv2LwhOpcWxTjeUunYqOmqd6hEoRDhtDWdA8ApRYsSUCDHNt5ul13vz4w0vWCgUnnEc975arX6ORqN3VqtVZbfbTQC4uEHANM3jSqXymFI6yWazP2KxWAXAL9zCUa1Wy2tXVxheKA9YNoR8Pt+aTqe4FVVVvz05O6MBhqUIBGk8Hn8HAOVy+T+XLJfLS4ZhTiRJgqIoVBRFIoric47jPnmeB1mW/9rr9ZpSSn3Lsmir1fJZlqWlUonKsvwWwD8ymc/nXwVBeLjf7xEKhdBut9Hr9WgmkyGEkJwsy5eHG5vN5g0AKIoCAEgkEkin0wQAfN9/cXPdheu6P33fBwB4ngcAcByHJpPJl+fn54mD3Gg0NrquXxeLRQAAwzAYj8cwTZPwPH9/sVg8PXweDAauqqr2cDjEer1GJBLBZDJBs9mE4zjwfZ85lAGg2+06hmGgXq+j3+/DsixYlgVN03a9Xu8jgCNCyIegIAgx13Vfd7vdu+FweG8YRkjXdWy329+dTgeSJD3ieZ7RNO0VAXAPwDEAO5VKndi2fWrb9jWl9Esul6PZbDY9Go1OZ7PZ9z/lyuD3OozU2wAAAABJRU5ErkJggg==</xsl:attribute>
          <xsl:attribute name="alt">[LOGO]</xsl:attribute>
        </xsl:element>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!--  ======================================================================
       Tables of Contents.
       ====================================================================== -->

  <xsl:strip-space elements="ltx:TOC ltx:toclist ltx:tocentry"/>
  <xsl:template match="ltx:TOC/ltx:title"/>

  <!-- explicitly requested TOC -->
  <xsl:template match="ltx:TOC[@format='short']">
    <xsl:param name="context"/>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name='add_attributes'>
        <xsl:with-param name="extra_classes" select="f:class-pref('ltx_toc_',@lists)"/>
      </xsl:call-template>
      <xsl:apply-templates mode="short">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:TOC[@format='veryshort']">
    <xsl:param name="context"/>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name='add_attributes'>
        <xsl:with-param name="extra_classes" select="f:class-pref('ltx_toc_',@lists)"/>
      </xsl:call-template>
      <xsl:apply-templates mode="veryshort">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:TOC[@format='normal2']">
    <xsl:param name="context"/>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name='add_attributes'>
        <xsl:with-param name="extra_classes" select="f:class-pref('ltx_toc_',@lists)"/>
      </xsl:call-template>
      <xsl:apply-templates mode="normal2">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:TOC">
    <xsl:param name="context"/>
    <xsl:if test="ltx:toclist/descendant::ltx:tocentry">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="div" namespace="{$html_ns}">
        <xsl:call-template name='add_attributes'>
          <xsl:with-param name="extra_classes" select="f:class-pref('ltx_toc_',@lists)"/>
        </xsl:call-template>
        <xsl:if test="ltx:title">
          <xsl:element name="h6" namespace="{$html_ns}">
            <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
            <xsl:apply-templates select="ltx:title/node()">
              <xsl:with-param name="context" select="$innercontext"/>
            </xsl:apply-templates>
          </xsl:element>
        </xsl:if>
        <xsl:apply-templates>
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:toclist" mode="short">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name='add_attributes'>
        <xsl:with-param name="extra_classes" select="'ltx_toc_compact'"/>
      </xsl:call-template>
      <xsl:text>&#x0A;&#x2666; </xsl:text>
      <xsl:apply-templates mode="short">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:toclist" mode="veryshort">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name='add_attributes'>
        <xsl:with-param name="extra_classes" select="'ltx_toc_verycompact'"/>
      </xsl:call-template>
      <xsl:text>&#x2666;</xsl:text>
      <xsl:apply-templates mode="veryshort">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:toclist">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="ul" namespace="{$html_ns}">
      <xsl:call-template name='add_id'/>
      <xsl:call-template name='add_attributes'/>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:toclist" mode="normal2">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:apply-templates select="." mode="twocolumn">
      <xsl:with-param name="context" select="$context"/>
    </xsl:apply-templates>
  </xsl:template>
  <xsl:template match="ltx:toclist" mode="twocolumn">
    <xsl:param name="context"/>
    <xsl:param name="items"    select="ltx:tocentry"/>
    <xsl:param name="lines"    select="descendant::ltx:tocentry"/>
    <xsl:param name="halflines" select="ceiling(count($lines) div 2)"/>
    <xsl:param name="miditem"
               select="count($lines[position() &lt; $halflines]/ancestor::ltx:tocentry[parent::ltx:toclist[parent::ltx:TOC]]) + 1"/>
    <xsl:call-template name="split-columns">
      <xsl:with-param name="context" select="$context"/>
      <xsl:with-param name="wrapper" select="'ul'"/>
      <xsl:with-param name="items"   select="$items"/>
      <xsl:with-param name="miditem" select="$miditem"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="ltx:tocentry">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="li" namespace="{$html_ns}">
      <xsl:call-template name='add_id'/>
      <xsl:call-template name='add_attributes'/>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:tocentry" mode="short">
    <xsl:param name="context"/>
    <xsl:apply-templates>
      <xsl:with-param name="context" select="$context"/>
    </xsl:apply-templates>
    <xsl:text> &#x2666; </xsl:text>
  </xsl:template>

  <xsl:template match="ltx:tocentry" mode="veryshort">
    <xsl:param name="context"/>
    <xsl:apply-templates>
      <xsl:with-param name="context" select="$context"/>
    </xsl:apply-templates>
    <xsl:text>&#x2666;</xsl:text>
  </xsl:template>

</xsl:stylesheet>
