<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-structure-xhtml.xsl                                        |
|  Converting documents structure to xhtml                            |
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
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:func  = "http://exslt.org/functions"
    xmlns:exsl  = "http://exslt.org/common"
    extension-element-prefixes="f func exsl"
    exclude-result-prefixes = "ltx f func exsl">

  <!-- whether to split index lists into two columns -->
  <xsl:param name="twocolumn-indexlist"></xsl:param>
  <!-- whether to split glossary lists into two columns -->
  <xsl:param name="twocolumn-glossarylist"></xsl:param>

  <!-- ======================================================================
       Document Structure
       ====================================================================== -->

  <xsl:template match="ltx:document  | ltx:part | ltx:chapter
		       | ltx:section | ltx:subsection | ltx:subsubsection
		       | ltx:paragraph | ltx:subparagraph
		       | ltx:bibliography | ltx:appendix | ltx:index | ltx:glossary
		       | ltx:slide | ltx:sidebar">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:if($USE_HTML5,'section','div')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:titlepage">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:creator[@role='author']">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:personname">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:choose>
	<xsl:when test="@href">
	  <xsl:element name="a" namespace="{$html_ns}">
	    <xsl:attribute name="href"><xsl:value-of select="f:url(@href)"/></xsl:attribute>
	    <xsl:apply-templates/>
	  </xsl:element>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:apply-templates/>
	</xsl:otherwise>
      </xsl:choose>
      <xsl:text>&#x0A;</xsl:text>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='address' or @role='affiliation']">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='email']">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:element name="a" namespace="{$html_ns}">      
	<xsl:attribute name="href"><xsl:value-of select="concat('mailto:',text())"/></xsl:attribute>
	<xsl:apply-templates/>
      </xsl:element>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='dedicatory']">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:abstract">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:if test="@name">
	<xsl:element name="h6" namespace="{$html_ns}">	
	  <xsl:apply-templates select="@name"/>
	</xsl:element>
      </xsl:if>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:acknowledgements">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:if test="@name">
	<xsl:text>&#x0A;</xsl:text>
	<xsl:element name="h6" namespace="{$html_ns}">	
	  <xsl:apply-templates select="@name"/>
	  <xsl:text>.</xsl:text>
	</xsl:element>
      </xsl:if>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:keywords">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:if test="@name">
	<xsl:text>&#x0A;</xsl:text>
	<xsl:element name="h6" namespace="{$html_ns}">
	  <xsl:apply-templates select="@name"/>
	  <xsl:text>:</xsl:text>
	</xsl:element>
      </xsl:if>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:classification">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:element name="h6" namespace="{$html_ns}"> <!--should be italic ? -->
	<xsl:choose>
	  <xsl:when test='@scheme'><xsl:value-of select='@scheme'/></xsl:when>
	  <xsl:when test='@name'><xsl:value-of select='@name'/></xsl:when>
	</xsl:choose>
	<xsl:text>: </xsl:text>
      </xsl:element>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <!--  ======================================================================
       Titles.
       ====================================================================== -->
  <!-- Hack to determine the `levels' of various sectioning.
       Given that the nesting could consist of any of
       document/part/chapter/section or appendix/subsection/subsubsection
       /paragraph/subparagraph
       We'd like to assign h1,h2,... sensibly.
       Or should the DTD be more specific? -->

  <xsl:param name="title_level">6</xsl:param>

  <!-- Awkward bit of logic to determine the heading level for the title of a sectional unit.
       We may have a full book document starting with parts, chapters, etc, (so sections are lower)
       OR have a page pulled out, of a section (so the section is top-level IN THIS PAGE).
       Note that there may be subsections in a doc, but a particular paragraph's parent
       may be a section, not a subsection! We still want consistent layout & styling.
       Additional complication is that bibligraphy (etc) may be section or chapter level. -->

  <func:function name="f:section-head-level">
    <xsl:param name="node"/>
    <xsl:param name="value" select="f:section-level($node)"/>
    <func:result><xsl:value-of select="f:if($value > 6, 6, $value)"/></func:result>
  </func:function>

  <func:function name="f:section-level">
    <xsl:param name="node"/>
    <xsl:param name="name" select="local-name($node)"/>
    <xsl:param name="level" select="f:seclev-aux($name)"/>
    <func:result>
      <xsl:choose>
	<xsl:when test="$level > 0"><xsl:value-of select="$level"/></xsl:when>
        <!-- Fallback: If some ancestor has a title, we're 1 deeper than its level -->
	<xsl:when test="exsl:node-set($node)/ancestor::*[ltx:title]">
	  <xsl:value-of select="1+f:section-level(exsl:node-set($node)/ancestor::*[ltx:title][1])"/>
	</xsl:when>
	<!-- Otherwise, whatever we are, we're the top level(?) -->
	<xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </func:result>
  </func:function>
  
  <!-- Attempt computing level based on "known" structural elements -->
  <func:function name="f:seclev-aux">
    <xsl:param name="name"/>
    <func:result>
      <xsl:choose>
	<xsl:when test="$name = 'document'">1</xsl:when>
	<xsl:when test="$name = 'part'"><!-- The logic: 1+doc level, if there IS a ltx:document-->
	  <xsl:value-of select="f:seclev-aux('document')+number(boolean(//ltx:document/ltx:title))"/>
	</xsl:when>
	<xsl:when test="$name = 'chapter'">
	  <xsl:value-of select="f:seclev-aux('part')+number(boolean(//ltx:part/ltx:title))"/>
	</xsl:when>
	<xsl:when test="$name = 'section'">
	  <xsl:value-of select="f:seclev-aux('chapter')+number(boolean(//ltx:chapter/ltx:title))"/>
	</xsl:when>
	<!-- These are same level as chapter, if there IS a chapter, otherwise same as section-->
	<xsl:when test="$name = 'appendix' or $name = 'index'
			or $name = 'glossary' or $name = 'bibliography'">
	  <xsl:value-of
	      select="f:if(//ltx:chapter,f:seclev-aux('chapter'),f:seclev-aux('section'))"/>
	</xsl:when>
	<xsl:when test="$name = 'subsection'"> <!--Weird? (could be in appendix!)-->
	  <xsl:value-of select="f:seclev-aux('section')
				+number(boolean(//ltx:section/ltx:title | //ltx:appendix/ltx:title))"/>
	</xsl:when>
	<xsl:when test="$name = 'subsubsection'">
	  <xsl:value-of select="f:seclev-aux('subsection')
				+number(boolean(//ltx:subsection/ltx:title))"/>
	</xsl:when>
	<xsl:when test="$name = 'paragraph'">
	  <xsl:value-of select="f:seclev-aux('subsubsection')
				+number(boolean(//ltx:subsubsection/ltx:title))"/>
	</xsl:when>
	<xsl:when test="$name = 'subparagraph'">
	  <xsl:value-of select="f:seclev-aux('paragraph')
				+number(boolean(//ltx:paragraph/ltx:title))"/>
	</xsl:when>
	<xsl:when test="$name = 'theorem' or $name = 'proof'">6</xsl:when> <!--what else?-->
      </xsl:choose>
    </func:result>
  </func:function>

  <xsl:template match="ltx:title">
    <!-- Skip title, if the parent has a titlepage! -->
    <xsl:if test="not(parent::*/child::ltx:titlepage)">    
      <xsl:text>&#x0A;</xsl:text>
      <xsl:choose>
	<xsl:when test="$USE_HTML5">
	  <xsl:element name="hgroup" namespace="{$html_ns}">
	    <xsl:call-template name="maketitle"/>
	  </xsl:element>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:call-template name="maketitle"/>
	</xsl:otherwise>
      </xsl:choose>	  
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:title" mode="classes">
    <xsl:apply-imports/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="concat('ltx_title_',local-name(..))"/>
  </xsl:template>

  <!-- theorem & proof titles aren't quite the same as sectional ones...?
       However, need to define it here, so it's precedence against
       plain ole ltx:title can be better controlled-->
  <xsl:template match="ltx:theorem/ltx:title | ltx:proof/ltx:title">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="h6" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <!-- Convert a title to an <h1>..<h6>, with appropriate classes and content,
       depending on the sectioning level & whether we're using html5 (only h1). -->
  <xsl:template name="maketitle">
    <xsl:element
	name="{f:if($USE_HTML5,'h1',concat('h',f:section-head-level(parent::*)))}"
	namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
    </xsl:element>
    <!-- include parent's subtitle & date (if any)-->
    <xsl:apply-templates select="../ltx:subtitle" mode="intitle"/>
    <xsl:apply-templates select="../ltx:date" mode="intitle"/>
    <xsl:apply-templates select="." mode="end"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:apply-templates select="parent::*" mode="auto-toc"/>
  </xsl:template>

  <!-- If we want to deduce style & children, we could set this up as a parameter option -->
  <xsl:template match="*|/" mode="auto-toc"/>

  <!-- only place the date & subtitle within the title treatment -->
  <xsl:template match="ltx:date"/>

  <!-- Apparently html5's hgroup doesn't like div, but perhaps h2 is more appropriate!-->
  <xsl:template match="ltx:date" mode="intitle">
    <xsl:text>&#x0A;</xsl:text>
<!--    <xsl:element name="div" namespace="{$html_ns}">-->
    <xsl:element name="{f:if($USE_HTML5,'h2','div')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="//ltx:document/ltx:date/node()"/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:subtitle"/>

  <!-- NOTE: Probably should support font, punct, etc, right? -->
  <xsl:template match="ltx:subtitle" mode="intitle">
    <xsl:text>&#x0A;</xsl:text>
    <!-- Since html5 uses h1 exclusively, h2 is safe and sensible here-->
    <!-- ORR could use the title-level + 1 -->
    <xsl:element name="{f:if($USE_HTML5,'h2','div')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:toctitle"/>

  <!-- ======================================================================
       Indices
       ====================================================================== -->

  <xsl:template match="ltx:indexlist">
    <xsl:choose>
      <xsl:when test="$twocolumn-indexlist and not(ancestor::ltx:indexlist)">
	<xsl:apply-templates select="." mode="twocolumn"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:text>&#x0A;</xsl:text>
	<xsl:element name="ul" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	</xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:indexlist" mode="twocolumn">
    <xsl:param name="items"    select="ltx:indexentry"/>
    <xsl:param name="lines"    select="descendant::ltx:indexphrase"/>
    <xsl:param name="halflines" select="ceiling(count($lines) div 2)"/>
    <xsl:param name="miditem"
	       select="count($lines[position() &lt; $halflines]/ancestor::ltx:indexentry[parent::ltx:indexlist[parent::ltx:index]]) + 1"/>
    <xsl:call-template name="split-columns">
      <xsl:with-param name="wrapper" select="'ul'"/>
      <xsl:with-param name="items"   select="$items"/>
      <xsl:with-param name="miditem" select="$miditem"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="ltx:indexentry">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="li" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="ltx:indexphrase"/>
      <xsl:apply-templates select="ltx:indexrefs"/>
      <xsl:apply-templates select="ltx:indexlist"/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:indexrefs">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Glossaries
       ====================================================================== -->

  <xsl:template match="ltx:glossarylist">
    <xsl:choose>
      <xsl:when test="$twocolumn-glossarylist">
	<xsl:apply-templates select="." mode="twocolumn"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:text>&#x0A;</xsl:text>
	<xsl:element name="dl" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	</xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:glossarylist" mode="twocolumn">
    <xsl:param name="items"    select="ltx:glossaryentry"/>
    <xsl:param name="miditem"
	       select="ceiling(count($items) div 2)+1"/>
    <xsl:call-template name="split-columns">
      <xsl:with-param name="wrapper" select="'dl'"/>
      <xsl:with-param name="items"   select="$items"/>
      <xsl:with-param name="miditem" select="$miditem"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="ltx:glossaryentry">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="dt" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="ltx:glossaryphrase"/>
    </xsl:element>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="dd" namespace="{$html_ns}">
      <xsl:apply-templates select="ltx:glossarydefinition"/>
      <xsl:apply-templates select="ltx:indexrefs"/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
