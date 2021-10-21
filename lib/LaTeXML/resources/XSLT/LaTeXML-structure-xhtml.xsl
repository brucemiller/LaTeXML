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
  <xsl:param name="USE_TWOCOLUMN_INDEX"></xsl:param>
  <!-- whether to split glossary lists into two columns -->
  <xsl:param name="USE_TWOCOLUMN_GLOSSARY"></xsl:param>

  <!-- ======================================================================
       Document Structure
       ====================================================================== -->

  <!-- We don't really anticipate document structure appearing in inline contexts,
       so we pretty much ignore the $context switches.
       However, a few elements like title do switch to inline.
       See the CONTEXT discussion in LaTeXML-common -->

  <xsl:strip-space elements="ltx:document ltx:part ltx:chapter ltx:section ltx:subsection
                             ltx:subsubsection ltx:paragraph ltx:subparagraph
                             ltx:bibliography ltx:appendix ltx:index ltx:glossary
                             ltx:slide ltx:sidebar"/>

  <xsl:template match="ltx:tag[@role]"/>

  <!-- Don't display tags; they're in the title -->
  <xsl:template match="ltx:document/ltx:tags | ltx:part/ltx:tags | ltx:chapter/ltx:tags
                       | ltx:section/ltx:tags | ltx:subsection/ltx:tags | ltx:subsubsection/ltx:tags
                       | ltx:paragraph/ltx:tags | ltx:subparagraph/ltx:tags
                       | ltx:bibliography/ltx:tags | ltx:appendix/ltx:tags | ltx:index/ltx:tags | ltx:glossary/ltx:tags
                       | ltx:sidebar/ltx:tags | ltx:slide/ltx:tags"/>

  <xsl:template match="ltx:document | ltx:part | ltx:chapter
                       | ltx:section | ltx:subsection | ltx:subsubsection
                       | ltx:paragraph | ltx:subparagraph
                       | ltx:bibliography | ltx:appendix | ltx:index | ltx:glossary
                       | ltx:slide">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:if($USE_HTML5,f:if(local-name(.) = 'document','article','section'),'div')}"
                 namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <!-- same, but move author to end -->
  <xsl:template match="ltx:sidebar">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:if($USE_HTML5,'article','div')}"
                 namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="*[not(./ltx:creator)]">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:call-template name="sidebarauthordate"/>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>


  <xsl:template match="ltx:abstract">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:if test="@name">
        <xsl:element name="h6" namespace="{$html_ns}">
          <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
          <xsl:attribute name="class">ltx_title ltx_title_abstract</xsl:attribute>
          <xsl:apply-templates select="@name">
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:if>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:acknowledgements">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:if test="@name">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="h6" namespace="{$html_ns}">
          <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
          <xsl:attribute name="class">ltx_title ltx_title_acknowledgements</xsl:attribute>
          <xsl:apply-templates select="@name">
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
          <xsl:text>.</xsl:text>
        </xsl:element>
      </xsl:if>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:preserve-space elements="ltx:keywords"/>
  <xsl:template match="ltx:keywords">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:if test="@name">
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="h6" namespace="{$html_ns}">
          <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
          <xsl:attribute name="class">ltx_title ltx_title_keywords</xsl:attribute>
          <xsl:apply-templates select="@name">
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
          <xsl:text>: </xsl:text>
        </xsl:element>
      </xsl:if>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:preserve-space elements="ltx:classification"/>
  <xsl:template match="ltx:classification">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:element name="h6" namespace="{$html_ns}"> <!--should be italic ? -->
        <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
        <xsl:attribute name="class">ltx_title ltx_title_classification</xsl:attribute>
        <xsl:choose>
          <xsl:when test='@scheme'><xsl:value-of select='@scheme'/></xsl:when>
          <xsl:when test='@name'><xsl:value-of select='@name'/></xsl:when>
        </xsl:choose>
        <xsl:text>: </xsl:text>
      </xsl:element>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
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
<!--          <xsl:value-of select="f:seclev-aux('document')+number(boolean(//ltx:document/ltx:title))"/>-->
          <xsl:value-of select="f:seclev-aux('document')+number(boolean(//ltx:document))"/>
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

  <xsl:preserve-space elements="ltx:title"/>
  <xsl:template match="ltx:title">
    <xsl:param name="context"/>
    <!-- Skip title, if the parent has a titlepage, or if writing a cv! -->
    <xsl:if test="not(parent::*/child::ltx:titlepage)">
      <xsl:text>&#x0A;</xsl:text>
      <!-- In html5, could have wrapped in hgroup, but that was deprecated -->
      <xsl:call-template name="maketitle">
        <xsl:with-param name="context" select="$context"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:strip-space elements="ltx:titlepage"/>

  <xsl:template match="ltx:titlepage">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:title" mode="classes">
    <xsl:apply-templates select="." mode="base-classes"/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="concat('ltx_title_',local-name(..))"/>
  </xsl:template>

  <!-- theorem & proof titles aren't quite the same as sectional ones...?
       However, need to define it here, so it's precedence against
       plain ole ltx:title can be better controlled-->
  <xsl:template match="ltx:theorem/ltx:title | ltx:proof/ltx:title">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="h6" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <!-- Convert a title to an <h1>..<h6>, with appropriate classes and content.
       In html5, IFF section/article elements are used, we can (& should?) use only h1.
       The title chunk also contains authors, subtitles, etc. -->
    <!-- or maybe not? seems the w3c validator is recommending against using h1 everywhere
     name="{concat('h',f:section-head-level(parent::*))}"
     name="{f:if($USE_HTML5,'h1',concat('h',f:section-head-level(parent::*)))}" -->
  <xsl:template name="maketitle">
    <xsl:param name="context"/>
    <xsl:element name="{concat('h',f:section-head-level(parent::*))}" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
    </xsl:element>
    <!-- include parent's subtitle, author & date (if any)-->
    <xsl:apply-templates select="../ltx:subtitle" mode="intitle">
      <xsl:with-param name="context" select="$context"/>
    </xsl:apply-templates>
    <xsl:if test="not(parent::ltx:sidebar)">
      <xsl:call-template name="authors">
        <xsl:with-param name="context" select="$context"/>
      </xsl:call-template>
      <xsl:if test="not(//ltx:navigation/ltx:ref[@rel='up'])">
        <xsl:call-template name="dates">
          <xsl:with-param name="context" select="$context"/>
          <xsl:with-param name="dates" select="../ltx:date"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
    <xsl:apply-templates select="." mode="end">
      <xsl:with-param name="context" select="$context"/>
    </xsl:apply-templates>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:apply-templates select="parent::*" mode="auto-toc">
      <xsl:with-param name="context" select="$context"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template name="sidebarauthordate">
    <xsl:param name="context"/>
    <xsl:element name="div" namespace="{$html_ns}">
        <xsl:attribute name="class">ltx_sidebar_authors</xsl:attribute>
        <xsl:if test="ltx:creator[@role='author']">
          <xsl:text>&#x0A;</xsl:text>
          <xsl:element name="div" namespace="{$html_ns}">
            <xsl:attribute name="class">ltx_authors</xsl:attribute>
            <xsl:apply-templates select="ltx:creator[@role='author']" mode="intitle">
              <xsl:with-param name="context" select="$context"/>
            </xsl:apply-templates>
          </xsl:element>
        </xsl:if>
      <xsl:call-template name="dates">
        <xsl:with-param name="context" select="$context"/>
        <xsl:with-param name="dates" select="ltx:date"/>
      </xsl:call-template>
    </xsl:element>
  </xsl:template>

  <!-- try to accomodate multiple authors in single block, vs each one as a block -->
  <xsl:template name="authors">
    <xsl:param name="context"/>
    <xsl:if test="../ltx:creator[@role='author']">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="div" namespace="{$html_ns}">
        <xsl:attribute name="class">ltx_authors</xsl:attribute>
        <xsl:apply-templates select="../ltx:creator[@role='author']" mode="intitle">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:strip-space elements="ltx:creator ltx:contact"/>

  <xsl:template match="ltx:creator[@role='cv']">
      <div class="flex-grid">
      <div class="col-25">
        <h1 class="author-name">
          <xsl:value-of select="ltx:contact[@role='firstname']" />
          <xsl:text> </xsl:text>
          <xsl:value-of select="ltx:contact[@role='familyname']" />
        </h1>
        <h3 class="author-title">
          <xsl:apply-templates select="ltx:contact[@role='position']/ltx:inline-block" />
        </h3>
      </div>
      <div class="col-25">
      </div>
      <div class="col-50">
        <h4 class="author-contact">
          <xsl:apply-templates select="ltx:contact[@role='address']" />
          <br class="ltx_break"/>
          <xsl:apply-templates select="ltx:contact[@role='mobile']" />
          <br class="ltx_break"/>
          <xsl:apply-templates select="ltx:contact[@role='email']" />
          <br class="ltx_break"/>
          <xsl:apply-templates select="ltx:contact[@role='homepage']" />
       </h4>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="ltx:creator"/>

  <!-- Format an author 'inline' as part of an author block -->
  <xsl:template match="ltx:creator[@role='author']" mode="intitle">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:if test="@before">
      <xsl:element name="span" namespace="{$html_ns}">
        <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
        <xsl:attribute name="class">ltx_author_before</xsl:attribute>
        <xsl:value-of select="@before"/>
      </xsl:element>
    </xsl:if>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="ltx:personname">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:if test="ltx:contact">
        <xsl:element name="span" namespace="{$html_ns}">
          <xsl:attribute name="class">ltx_author_notes</xsl:attribute>
          <xsl:element name="span" namespace="{$html_ns}">
            <xsl:apply-templates select="ltx:contact">
              <xsl:with-param name="context" select="$innercontext"/>
            </xsl:apply-templates>
          </xsl:element>
        </xsl:element>
      </xsl:if>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
    </xsl:element>
    <xsl:if test="@after">
      <xsl:element name="span" namespace="{$html_ns}">
        <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
        <xsl:attribute name="class">ltx_author_after</xsl:attribute>
        <xsl:value-of select="@after"/>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:preserve-space elements="ltx:personname"/>
  <xsl:template match="ltx:personname">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:choose>
        <xsl:when test="@href">
          <xsl:element name="a" namespace="{$html_ns}">
            <xsl:attribute name="href"><xsl:value-of select="f:url(@href)"/></xsl:attribute>
            <xsl:apply-templates>
              <xsl:with-param name="context" select="$innercontext"/>
            </xsl:apply-templates>
          </xsl:element>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates>
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>&#x0A;</xsl:text>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:preserve-space elements="ltx:contact"/>
  <xsl:template match="ltx:contact[@role='address' or @role='affiliation']">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='email']">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:element name="a" namespace="{$html_ns}">
        <xsl:attribute name="href"><xsl:value-of select="concat('mailto:',text())"/></xsl:attribute>
        <xsl:apply-templates>
          <xsl:with-param name="context" select="$innercontext"/>
        </xsl:apply-templates>
      </xsl:element>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='homepage']">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:element name="a" namespace="{$html_ns}">
        <xsl:attribute name="href"><xsl:value-of select="text()"/></xsl:attribute>
        <xsl:apply-templates>
          <xsl:with-param name="context" select="$innercontext"/>
        </xsl:apply-templates>
      </xsl:element>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='dedicatory' or @role='mobile']">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>


  <!-- If we want to deduce style & children, we could set this up as a parameter option -->
  <xsl:template match="*|/" mode="auto-toc"/>

  <!-- only place the date & subtitle within the title treatment -->
  <xsl:preserve-space elements="ltx:date"/>
  <xsl:template match="ltx:date"/>

  <xsl:template name="dates">
    <xsl:param name="context"/>
    <xsl:param name="dates" select="ltx:date"/>
    <xsl:if test="$dates and normalize-space(string($dates))">
      <xsl:text>&#x0A;</xsl:text>
      <!-- Originally, html5 seemed to suggest we might use h2 here, but that is retracted-->
      <xsl:element name="div" namespace="{$html_ns}">
        <xsl:attribute name="class">ltx_dates</xsl:attribute>
        <xsl:apply-templates select="." mode="begin">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
        <xsl:text>(</xsl:text>
        <xsl:apply-templates select="$dates" mode="intitle">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
        <xsl:text>)</xsl:text>
        <xsl:apply-templates select="." mode="end">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:date" mode="intitle">
    <xsl:param name="context"/>
    <xsl:if test="@name"><xsl:value-of select="@name"/><xsl:text> </xsl:text></xsl:if>
    <xsl:apply-templates select="node()">
      <xsl:with-param name="context" select="$context"/>
    </xsl:apply-templates>
    <xsl:if test="following-sibling::ltx:date"><xsl:text>; </xsl:text></xsl:if>
  </xsl:template>

  <xsl:preserve-space elements="ltx:subtitle"/>
  <xsl:template match="ltx:subtitle"/>

  <!-- NOTE: Probably should support font, punct, etc, right? -->
  <xsl:template match="ltx:subtitle" mode="intitle">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <!-- Originally, html5 seemed to suggest using h2 here, but that is retracted-->
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:preserve-space elements="ltx:toctitle"/>
  <xsl:template match="ltx:toctitle"/>

  <!-- ======================================================================
       Indices
       ====================================================================== -->

  <xsl:strip-space elements="ltx:indexlist ltx:indexentry"/>

  <xsl:template match="ltx:indexlist">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$USE_TWOCOLUMN_INDEX and not(ancestor::ltx:indexlist)">
        <xsl:apply-templates select="." mode="twocolumn">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="ul" namespace="{$html_ns}">
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes"/>
          <xsl:apply-templates select="." mode="begin">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates>
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="." mode="end">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:indexlist" mode="twocolumn">
    <xsl:param name="context"/>
    <xsl:param name="items"    select="ltx:indexentry"/>
    <xsl:param name="lines"    select="descendant::ltx:indexphrase"/>
    <xsl:param name="halflines" select="ceiling(count($lines) div 2)"/>
    <xsl:param name="miditem"
               select="count($lines[position() &lt; $halflines]/ancestor::ltx:indexentry[parent::ltx:indexlist[parent::ltx:index]]) + 1"/>
    <xsl:call-template name="split-columns">
      <xsl:with-param name="context" select="$context"/>
      <xsl:with-param name="wrapper" select="'ul'"/>
      <xsl:with-param name="items"   select="$items"/>
      <xsl:with-param name="miditem" select="$miditem"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="ltx:indexentry">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="li" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="ltx:indexphrase">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="ltx:indexrefs">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="ltx:indexlist">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:preserve-space elements="ltx:indexrefs"/>
  <xsl:template match="ltx:indexrefs">
    <xsl:param name="context"/>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Glossaries
       ====================================================================== -->

  <xsl:strip-space elements="ltx:glossarlist ltx:glossaryentry"/>

  <xsl:template match="ltx:glossarylist">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$USE_TWOCOLUMN_GLOSSARY">
        <xsl:apply-templates select="." mode="twocolumn">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>&#x0A;</xsl:text>
        <xsl:element name="dl" namespace="{$html_ns}">
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes"/>
          <xsl:apply-templates select="." mode="begin">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="ltx:glossaryentry">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="." mode="end">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:glossarylist" mode="twocolumn">
    <xsl:param name="context"/>
    <xsl:param name="items"    select="ltx:glossaryentry"/>
    <xsl:param name="miditem"
               select="ceiling(count($items) div 2)+1"/>
    <xsl:call-template name="split-columns">
      <xsl:with-param name="context" select="$context"/>
      <xsl:with-param name="wrapper" select="'dl'"/>
      <xsl:with-param name="items"   select="$items"/>
      <xsl:with-param name="miditem" select="$miditem"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="ltx:glossaryentry">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="dt" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="ltx:glossaryphrase[@role='label']">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="dd" namespace="{$html_ns}">
      <xsl:apply-templates select="ltx:glossaryphrase[@role='definition']">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="ltx:indexrefs">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:preserve-space elements="ltx:glossaryphrase"/>
  <xsl:template match="ltx:glossaryphrase[@role='acronym']"/>
</xsl:stylesheet>
