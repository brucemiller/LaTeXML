<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">
<!--
 /=====================================================================\ 
 |  LaTeXML.xsl                                                        |
 | Stylesheet for converting LaTeXML generated documents to HTML       |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<xsl:output method="html"
	    omit-xml-declaration='yes'
	    doctype-public = "-//W3C//DTD HTML 4.01 Transitional//EN"
            doctype-system = "http://www.w3c.org/TR/html4/loose.dtd"
	    media-type='text/html'/>

<xsl:param name="CSS"></xsl:param>

<!--  ======================================================================
      Copy Template; things that should just get copied straight through
      ====================================================================== -->

<xsl:template match="p | a | span | div | font | br
                     | colgroup | col | tr | td | th | thead | tbody | tfoot | hr">
    <xsl:element name="{name()}">
      <xsl:for-each select="@*">
        <xsl:attribute name="{name()}">
          <xsl:value-of select="."/>
        </xsl:attribute>
      </xsl:for-each>
      <xsl:apply-templates/>
    </xsl:element>
</xsl:template>

<xsl:template match="printonly"/>


<!--  ======================================================================
      The Page
      ====================================================================== -->

<xsl:template match="/">
  <html>
    <head>
      <!--      <title>DLMF: <xsl:value-of select="*/title/descendent::text()"/></title>-->
      <title><xsl:value-of select="*/title"/></title>
      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
      <xsl:if test='$CSS'>
	<link rel='stylesheet' type="text/css" href="{$CSS}"/> 
     </xsl:if>
    </head>
    <body>
      <xsl:call-template name="header"/>
      <div class="content">
        <xsl:apply-templates/>
      </div>
      <xsl:call-template name="footer"/> 
    </body>
  </html>
</xsl:template>

<xsl:template match="metakeywords">
  <meta name="keywords" lang="en-us" content="{@keywords}"/>
</xsl:template>

<!--  ======================================================================
      Header & Footer
      ====================================================================== -->

<xsl:template name="sep">
  <xsl:text> &#x2666; </xsl:text>
</xsl:template>

<xsl:template name="header">
  <div class='header'>
  </div>
</xsl:template>

<xsl:template name="footer">
  <div class='footer'>
    <xsl:value-of select='//creationdate/node()'/>
  </div>
</xsl:template>

<!-- ======================================================================
     Document Structure
     ====================================================================== -->

<xsl:template match="document | chapter | part | section 
              | subsection | subsubsection | paragraph | sidebar | bibliography | appendix">
  <div class="{name()}" id="{@label}">
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="author">
  <div class='author'>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="affiliation">
  <div class='affiliation'><xsl:apply-templates/></div>
</xsl:template>

<!-- for now, just ignore ... -->
<xsl:template match="creationdate"/>

<xsl:template match="gallery">
  <div class='gallery'>
    <xsl:apply-templates/>
  </div>
</xsl:template>
<xsl:template match="galleryitem">
  <a href="{@href}" class="galleryitem"><img src="{@src}" width='100' height='100' border='0'/></a>
</xsl:template>

<xsl:template name="add_id">
  <xsl:if test="@label">
    <xsl:attribute name="id"><xsl:value-of select="@label"/></xsl:attribute>
  </xsl:if>
</xsl:template>

<!--  ======================================================================
      Titles, Refnums and such
      ====================================================================== -->

<xsl:template match="document/title">
  <h1><xsl:call-template name="title-refnum"/><xsl:apply-templates /></h1>
</xsl:template>

<xsl:template match="part/title">
  <h2><xsl:call-template name="title-refnum"/><xsl:apply-templates/></h2>
</xsl:template>

<xsl:template match="chapter/title | bibliography/title">
  <h2><xsl:call-template name="title-refnum"/><xsl:apply-templates/></h2>
</xsl:template>

<xsl:template match="section/title">
  <h3><xsl:call-template name="title-refnum"/><xsl:apply-templates/></h3>
</xsl:template>

<xsl:template match="appendix/title">
  <h3>Appendix <xsl:call-template name="title-refnum"/><xsl:apply-templates/></h3>
</xsl:template>

<xsl:template match="subsection/title">
  <h4><xsl:call-template name="title-refnum"/><xsl:apply-templates/></h4>
</xsl:template>

<xsl:template match="subsubsection/title | paragraph/title">
  <h5><xsl:call-template name="title-refnum"/><xsl:apply-templates/></h5>
</xsl:template>

<xsl:template match="title">
  <h6><xsl:call-template name="title-refnum"/><xsl:apply-templates/></h6>
</xsl:template>

<xsl:template match="toctitle"/>

<!-- Refnums -->
<xsl:template match="@refnum[../@label]">
  <a name="{../@label}" class='refnum'><xsl:value-of select="."/></a><xsl:text> </xsl:text>
</xsl:template>

<xsl:template name="title-refnum">
  <xsl:if test="../@refnum">
    <span class="refnum">
      <xsl:value-of select="../@refnum"/>
    </span>
    <xsl:text> </xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="ref[text()] | qref[text()]">
  <a href="{concat('#',@labelref)}" class="refnum"><xsl:apply-templates/></a>
</xsl:template>

<xsl:template match="ref | qref">
  <a href="{concat('#',@labelref)}" class="refnum"><xsl:value-of select="@labelref"/></a>
</xsl:template>

<xsl:template match="eqref">(<a href="{concat('#',@labelref)}" class="refnum"><xsl:value-of select="@labelref"/></a>)</xsl:template>

<!-- ======================================================================
     Math level
     Really MathML !!!
     ====================================================================== -->
<xsl:template match="equation">
  <div class='equation'> 
  <xsl:call-template name="add_id"/>
    <xsl:apply-templates select="@refnum"/>
    <span class='equationcontent'>
      <xsl:apply-templates select="XMath"/>
    </span>
    <xsl:apply-templates select="constraint"/>
    <xsl:apply-templates select="@metalabel"/>
  </div>
</xsl:template>

<xsl:template match="XMath[@imagesrc]">
  <img src="{@imagesrc}" width="{@imagewidth}" height="{@imageheight}" alt="{@tex}" class='math'/>
</xsl:template>

<!-- ignore (if preceded by an XMath?) -->
<xsl:template match="punct"/>

<xsl:template match="equationmix">
  <div class='equation'> 
  <xsl:call-template name="add_id"/>
    <xsl:apply-templates select="@refnum"/>
    <span class='equationcontent'>
      <xsl:apply-templates/>
    </span>
    <xsl:apply-templates select="@metalabel"/>
  </div>
</xsl:template>

<xsl:template match="constraint[@hidden='yes']"/>
<xsl:template match="constraint">
  <span class='constraint'><xsl:apply-templates/></span>
</xsl:template>

<!-- ======================================================================
     Block Elements
     ====================================================================== -->

<xsl:template match="toccaption"/>
<xsl:template match="caption">
  <div class='caption'>  
    <xsl:apply-templates select="../@refnum"/>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="figure | table">
  <div class='{name()}'>
  <xsl:call-template name="add_id"/>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="figuregroup">
  <div class="figuregroup">
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="tabular">
  <table align='center'>
    <xsl:attribute name="frame"><xsl:value-of select="@frame"/></xsl:attribute>
    <xsl:attribute name="rules"><xsl:value-of select="@rules"/></xsl:attribute>
    <xsl:apply-templates/>
  </table>
</xsl:template>

<xsl:template match="graphics">
  <img src="{@src}" width="{@width}" height="{@height}"/>
</xsl:template>

<xsl:template match="quote">
  <blockquote>
    <xsl:apply-templates/>
  </blockquote>
</xsl:template>
<!-- ======================================================================
     Lists
     ====================================================================== -->

<xsl:template name="copy-class">
  <xsl:if test="@class">
    <xsl:attribute name="class">
      <xsl:value-of select="@class"/>
    </xsl:attribute>
  </xsl:if>
</xsl:template>

<xsl:template match="itemize">
  <ul>
    <xsl:call-template name="copy-class"/>
    <xsl:apply-templates/></ul>
</xsl:template>
<xsl:template match="enumerate">
  <ol>
    <xsl:call-template name="copy-class"/>
    <xsl:apply-templates/></ol>
</xsl:template>
<xsl:template match="item">
  <li><xsl:apply-templates/></li>
</xsl:template>

<xsl:template match="description">
  <dl class="description">
    <xsl:call-template name="copy-class"/>
    <xsl:apply-templates mode='description'/></dl>
</xsl:template>
<xsl:template match="item" mode="description">
  <dt><xsl:value-of select="@tag"/><xsl:apply-templates select="tag/node()"/></dt><dd><xsl:apply-templates/></dd>
</xsl:template>

<xsl:template match="tag"/>
<!-- ======================================================================
     Inline Elements
     ====================================================================== -->

<xsl:template match="textup | textsl | textsc | textmd | textrm | textsf">
  <span class="{name()}"><xsl:apply-templates/></span>
</xsl:template>

<xsl:template match="textstyle[@font='typewriter']">
  <tt><xsl:apply-templates/></tt>
</xsl:template>
<xsl:template match="textstyle[@font='bold']">
  <b><xsl:apply-templates/></b>
</xsl:template>
<xsl:template match="textstyle[@font='italic']">
  <i><xsl:apply-templates/></i>
</xsl:template>

<xsl:template match="textstyle">
  <span class="{@font}"><xsl:apply-templates/></span>
</xsl:template>

<xsl:template match="textit">
  <i><xsl:apply-templates/></i>
</xsl:template>

<xsl:template match="emph">
  <em><xsl:apply-templates/></em>
</xsl:template>
<xsl:template match="textbf">
  <b><xsl:apply-templates/></b>
</xsl:template>
<xsl:template match="texttt">
  <tt><xsl:apply-templates/></tt>
</xsl:template>
<xsl:template match="text">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="cite[@style='intext']">
  <xsl:apply-templates select="citepre"/>
  <!--  <xsl:apply-templates select="bibref"/>-->
  <xsl:value-of select="@ref"/>
  <xsl:apply-templates select="citepost"/>
</xsl:template>

<xsl:template match="cite">
  (<xsl:apply-templates select="citepre"/>
<!-- <xsl:apply-templates select="bibref"/>-->
   <xsl:value-of select="@ref"/>
   <xsl:apply-templates select="citepost"/>)</xsl:template>

<xsl:template match="bibref">
  <a href="{@href}"><xsl:apply-templates/></a>
</xsl:template>

<xsl:template match="citepre[../@style='intext'] | citepost[../@style='intext']"
  >(<xsl:apply-templates/>)</xsl:template>
<xsl:template match="citepre"><xsl:apply-templates/><xsl:text> </xsl:text></xsl:template>
<xsl:template match="citepost">; <xsl:apply-templates/></xsl:template>

<xsl:template match="VRML">
  <a href="{@href}">VRML</a>
</xsl:template>

<!-- ======================================================================
     The Index
     ====================================================================== -->
<xsl:template match="indexentry">
  <li id="{@label}">
   <span class='indexline'>
    <xsl:apply-templates select="indexlevel"/>
    <xsl:apply-templates select="indexrefs"/>
  </span>
  <xsl:apply-templates select="indexlist"/>
  </li>
</xsl:template>
<xsl:template match="indexlevel[../@label]">
  <a name="{../@label}" class="indexlevel">
    <xsl:apply-templates/>
  </a>
</xsl:template>
<xsl:template match="indexlevel">
  <span class="indexlevel">
    <xsl:apply-templates/>
  </span>
</xsl:template>
<xsl:template match="indexrefs">
  <xsl:text> </xsl:text>
  <xsl:apply-templates/>
</xsl:template>
<xsl:template match="indexlist">
  <ul class="indexlist">
    <xsl:apply-templates/>
  </ul>
</xsl:template>


<!-- ======================================================================
     Bibliography
     ====================================================================== -->
<xsl:template match="biblist">
  <ul class="biblist">
    <xsl:apply-templates/>
  </ul>
</xsl:template>

<xsl:template match="bibitem">
  <li id="{@label}" class="bibitem">
    <a name="{@label}" class="bib-ay"><xsl:apply-templates select="fbib-author-year"/></a>
    <xsl:apply-templates select="fbib-title | fbib-data | fbib-extra"/>
</li>
</xsl:template>
<xsl:template match="fbib-title | fbib-data | fbib-extra">
  <br/><xsl:apply-templates/>
</xsl:template>

<xsl:template match="bib-mr">
  <a href="{concat('http://www.ams.org/mathscinet-getitem?mr=',text())}"><xsl:apply-templates/>(MathRev)</a>
</xsl:template>
<xsl:template match="bib-doi">
  <a href="{concat('http://dx.doi.org/',text())}"><xsl:apply-templates/></a>
</xsl:template>
<xsl:template match="bib-url">
  <a href="{concat('http://dx.doi.org/',text())}"><xsl:apply-templates/></a>
</xsl:template>

<!-- ======================================================================
     Meta data
     ====================================================================== -->

<xsl:template match="email">
  <a href="{concat('mailto:',text())}"><xsl:value-of select="text()"/></a>
</xsl:template>

<xsl:template match="metadata">
  <dl class="metadata">
    <xsl:apply-templates/>
  </dl>
</xsl:template>

<xsl:template match="sources">
  <dt>Sources</dt>
  <dd><ul><xsl:apply-templates/></ul></dd>
</xsl:template>
<xsl:template match="source">
  <li class="source"><xsl:apply-templates select="node()"/></li>
</xsl:template>

<xsl:template match="notes">
  <dt>Notes</dt>
  <dd><ul><xsl:apply-templates/></ul></dd>
</xsl:template>
<xsl:template match="note">
  <li class="note"><xsl:apply-templates select="node()"/></li>
</xsl:template>

<xsl:template match="keywords">
  <dt>Keywords</dt>
  <dd class="keywords"><ul><li><xsl:apply-templates/></li></ul></dd>
</xsl:template>
<xsl:template match="keyword">
  <a href="{@href}" class="keyword"><xsl:apply-templates/></a>
</xsl:template>

<xsl:template match="index"/>

<xsl:template match="origrefs">
  <dt>A&amp;S Ref.</dt>
  <dd><ul><li><xsl:apply-templates/></li></ul></dd>
</xsl:template>
<xsl:template match="origref">
  <xsl:text> </xsl:text>
  <span class="origref"><span class="refnum"><xsl:value-of select="@ref"/></span>
    <xsl:if test="node()"> (<xsl:apply-templates select="node()"/>)</xsl:if>
  </span>
</xsl:template>

<xsl:template match="latex-encodings">
  <dt>LaTeX</dt>
  <dd class="encoding"><ul><li><xsl:apply-templates/></li></ul></dd>
</xsl:template>
<xsl:template match="encoding">
  <xsl:text> </xsl:text>
  <a href="{concat('data:text/plain;base64,',text())}"><xsl:value-of select="@aboutrefnum"/></a>
</xsl:template>

<xsl:template match="referrers">
  <dt>Ref'd&#160;by</dt>
  <dd class="referrers"><ul><li><xsl:apply-templates/></li></ul></dd>
</xsl:template>
<xsl:template match="referrer">
  <a href="{@href}" class='referrer'><xsl:apply-templates/></a>
</xsl:template>

<xsl:template match="acknowledgements">
  <dt>Acknowledgments</dt>
  <dd class='acknowledgements'><xsl:apply-templates select="node()"/></dd>
</xsl:template>

<!-- ======================================================================
     Search Hit List
     ====================================================================== -->

<xsl:template match="hitlist">
  <div class="hitlist"><xsl:apply-templates/></div>
</xsl:template>

<xsl:template match="hit">
  <h4><em>In </em><xsl:apply-templates select="ancestry" mode="hitancestry"/></h4>
  <h5><xsl:apply-templates select="hittag"/></h5>
  <xsl:apply-templates select="hitcontent"/>
</xsl:template>

<xsl:template match="hittag">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="ancestry" mode="hitancestry">
  <xsl:apply-templates select="ancestry" mode="hitancestry"/>
  <xsl:if test="ancestry">
    <xsl:text>; </xsl:text>
  </xsl:if>
  <xsl:apply-templates select="reftitle"/>
</xsl:template>

<xsl:template match="hitcontent">
  <div class="hitcontent"><xsl:apply-templates/></div>
</xsl:template>

<!-- HACK !!! -->
<xsl:template match="hit//meta-equation | hit//meta-equationmix | hit//meta-figure | hit//meta-table"/>


</xsl:stylesheet>
