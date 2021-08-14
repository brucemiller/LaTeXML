<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\
|  LaTeXML-jats.xsl                                                   |
|  Stylesheet for converting LaTeXML documents to JATS/NLM            |
|=====================================================================|
| Part of LaTeXML:                                                    |
|  Public domain software, produced as part of work done by the       |
|  United States Government & not subject to copyright in the US.     |
|=====================================================================|
| Thanks to Lukas Kohlhase formerly of Jacobs University, Bremen      |
| and Viacheslav Zholudev from ResearchGate;                          |
| Released to the Public Domain                                       |
|=====================================================================|
| Bruce Miller <bruce.miller@nist.gov>                        #_#     |
| http://dlmf.nist.gov/LaTeXML/                              (o o)    |
\=========================================================ooo==U==ooo=/
-->
<xsl:stylesheet
    version     ="1.0"
    xmlns:xsl   ="http://www.w3.org/1999/XSL/Transform"
    xmlns:ltx   ="http://dlmf.nist.gov/LaTeXML"
    xmlns:str   ="http://exslt.org/strings"
    xmlns:m     ="http://www.w3.org/1998/Math/MathML"
    xmlns:svg   ="http://www.w3.org/2000/svg"
    xmlns:xlink ="http://www.w3.org/1999/xlink"
    extension-element-prefixes="str"
    exclude-result-prefixes="ltx str m svg xlink">

  <!-- Possibly useful validator:
       https://www.ncbi.nlm.nih.gov/pmc/tools/xmlchecker/
       -->

  <xsl:import href="LaTeXML-tabular-xhtml.xsl"/>
  <xsl:import href="LaTeXML-common.xsl"/>

  <xsl:strip-space elements="ltx:document ltx:part ltx:chapter ltx:section ltx:subsection
                             ltx:subsubsection ltx:paragraph ltx:subparagraph
                             ltx:bibliography ltx:appendix ltx:index ltx:glossary
                             ltx:slide ltx:sidebar"/>
  <xsl:strip-space elements="ltx:TOC ltx:toclist ltx:tocentry"/>
  <xsl:strip-space elements="ltx:titlepage"/>
  <xsl:strip-space elements="ltx:creator ltx:contact"/>
  <xsl:strip-space elements="ltx:indexlist ltx:indexentry"/>
  <xsl:strip-space elements="ltx:glossarlist ltx:glossaryentry"/>
  <xsl:strip-space elements="ltx:tabular ltx:thead ltx:tbody ltx:tfoot ltx:tr"/>
  <xsl:strip-space elements="ltx:quote"/>
  <xsl:strip-space elements="ltx:block"/>
  <xsl:strip-space elements="ltx:listing"/>
  <xsl:strip-space elements="ltx:equation ltx:equationgroup"/>
  <xsl:strip-space elements="ltx:itemize ltx:enumerate ltx:description ltx:item
                             ltx:inline-itemize ltx:inline-enumerate ltx:inline-description ltx:inline-item"/>
  <xsl:strip-space elements="ltx:inline-block"/>
  <xsl:strip-space elements="ltx:para ltx:inline-para"/>
  <xsl:strip-space elements="ltx:theorem ltx:proof"/>
  <xsl:strip-space elements="ltx:figure ltx:table ltx:float"/>
  <xsl:strip-space elements="ltx:picture svg:*"/>

  <xsl:output
      method="xml"
      indent="yes"
      doctype-public = "-//NLM//DTD JATS (Z39.96) Journal Publishing DTD v1.2 20190208//EN"
      doctype-system = "JATS-journalpublishing1-2.dtd"
      />
  <!--
      doctype-public = "-//NLM//DTD JATS (Z39.96) Journal Publishing DTD v1.3 20210610//EN"
      doctype-system = "JATS-journalpublishing1-3.dtd"
  -->

  <xsl:variable name="footnotes" select="//ltx:note[@role='footnote']"/>
  <xsl:template name="add_classes"/>
  <xsl:param name="html_ns"></xsl:param>
  <xsl:param name="USE_XMLID"></xsl:param>

  <!-- ======================================================================
       Basic Document structure -->
  <xsl:template match="ltx:document">
    <!-- we need to partition the top-level elements into frontmatter, body and backmatter -->
    <article>
      <front>
        <journal-meta>
          <journal-id>not-yet-known</journal-id>
          <issn>not-yet-known</issn>
        </journal-meta>
        <article-meta>
          <article-id>not-yet-known</article-id>
          <xsl:apply-templates select="ltx:title"/>
          <contrib-group>
            <xsl:apply-templates select="ltx:creator[@role='author']"/>
          </contrib-group>
          <xsl:apply-templates select="ltx:date[@role='creation']"/>
          <permissions><copyright-statement>unknown</copyright-statement></permissions>
          <xsl:apply-templates select="ltx:abstract"/>
          <xsl:apply-templates select="ltx:keywords"/>
        </article-meta>
      </front>
      <body>
        <xsl:apply-templates select="*[
                                     not(self::ltx:title or self::ltx:creator or self::ltx:date or self::ltx:abstract or self::ltx:keywords)
                                     and not(self::ltx:acknowledgements or self::ltx:bibliography)
                                     and not(self::ltx:appendix)]"/>
      </body>
      <back>
        <xsl:apply-templates select="ltx:acknowledgements"/>
        <xsl:apply-templates select="ltx:bibliography"/>
        <app-group>
          <xsl:apply-templates select="//ltx:appendix"/>
        </app-group>
      </back>
    </article>
  </xsl:template>

  <xsl:template match="ltx:para[not(ancestor::ltx:section or ancestor::ltx:appendix or ancestor::ltx:acknowledgements) and preceding::ltx:section]">  <!-- Is not allowed -->
    <xsl:comment><xsl:for-each select=".//text()"><xsl:value-of select="."/></xsl:for-each></xsl:comment> <!-- trying to provide the maximal information here -->
  </xsl:template>

  <!-- ======================================================================
       Some standard preliminaries -->

  <!-- In general, ltx:title maps to title -->
  <xsl:template match="ltx:title">
    <title>
      <xsl:apply-templates/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:toctitle"/>
  <xsl:template match="ltx:tags"/>
  <xsl:template match="ltx:tag"/>
  <xsl:template match="ltx:resource"/>

  <!-- Utility for elements which require their content to be in <p>..</p>
       where the content may or may not have an ltx:p -->
  <xsl:template name="require_p">
    <xsl:choose>
      <xsl:when test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
          <xsl:apply-templates/>
        </p>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ======================================================================
       Front matter section -->

  <xsl:template match="ltx:document/ltx:title">
    <title-group>
      <article-title>
        <xsl:apply-templates/>
      </article-title>
    </title-group>
  </xsl:template>

  <xsl:template match="ltx:titlepage">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:creator[@role='author']">
    <contrib contrib-type="author">
      <xsl:apply-templates/>
    </contrib>
  </xsl:template>

  <xsl:template match="ltx:title/ltx:tag">
    <xsl:value-of select="@open"/>
    <xsl:apply-templates/>
    <xsl:value-of select="@close"/>
  </xsl:template>

  <xsl:template match="ltx:date[@role='creation']">
    <pub-date><year><xsl:apply-templates /></year></pub-date>
  </xsl:template>

  <xsl:template match="ltx:creator">
    <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:contact"/> <!-- Unless specifically mapped -->

  <xsl:template match="ltx:contact[@role='affiliation']">
    <aff><xsl:apply-templates/></aff>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='email']">
    <email><xsl:apply-templates/></email>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='url']">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='address']">
    <address>
      <addr-line>
        <xsl:apply-templates/>
      </addr-line>
    </address>
  </xsl:template>

  <xsl:template match="ltx:note[@role='institutetext']"/>

  <xsl:template match="ltx:personname">
    <name>
      <surname>
        <xsl:for-each select="str:tokenize(./text(),' ')">
          <xsl:if test="position()=last()">
            <xsl:value-of select="."/>
          </xsl:if>
        </xsl:for-each>
      </surname>
      <given-names>
        <xsl:for-each select="str:tokenize(./text(),' ')">
          <xsl:if test="position()!=last()">
            <xsl:value-of select="."/>
          </xsl:if>
        </xsl:for-each>
      </given-names>
    </name>
  </xsl:template>

  <xsl:template match="ltx:abstract">
    <abstract>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </abstract>
  </xsl:template>

  <xsl:template match="ltx:keywords">
    <kwd-group>
      <xsl:for-each select="str:tokenize(./text(),',')">
        <kwd><xsl:value-of select="."/></kwd>
      </xsl:for-each>
    </kwd-group>
  </xsl:template>

  <xsl:template match="ltx:classification"/>

  <!-- ======================================================================
       Backmatter section -->

  <xsl:template match="ltx:bibliography">
    <ref-list>
      <xsl:apply-templates/>
    </ref-list>
  </xsl:template>

  <xsl:template match="ltx:biblist">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibitem">
    <ref>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <mixed-citation>
        <!-- Getting the reference type into the reference, if possible -->
        <xsl:if test="./ltx:tags/ltx:tag[@class='ltx_bib_type']">
          <xsl:attribute name="publication-type"> <xsl:value-of select="./ltx:tag[@class='ltx_bib_type']/text()"/></xsl:attribute>
        </xsl:if>
        <!-- Isn't this better?
             <xsl:if test="@type">
             <xsl:attribute name="publication-type"> <xsl:value-of select="@type"/></xsl:attribute>
             </xsl:if>
        -->
        <!--        <xsl:apply-templates select="node()"/>-->
        <xsl:apply-templates/>
      </mixed-citation>
    </ref>
  </xsl:template>

  <xsl:template match="ltx:appendix">
    <app>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </app>
  </xsl:template>

  <xsl:template match="ltx:tags">
    <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:tag[@class='ltx_bib_type']"/>
  <xsl:template match="ltx:tag[@role='key']"/>

  <xsl:template match="ltx:bibblock//ltx:bib-part[@role='publisher']">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-note[@role='publication']">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-part[@role='series']">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-publisher">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-edition">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibitem/ltx:tags/ltx:tag[@role='year']">
    <year>
      <xsl:apply-templates/>
    </year>
  </xsl:template>

  <xsl:template match="ltx:bib-part[@role='volume']">
    <volume>
      <xsl:apply-templates/>
    </volume>
  </xsl:template>

  <xsl:template match="ltx:bib-part[@role='pages']">
    <page-range>
      <xsl:apply-templates/>
    </page-range>
  </xsl:template>

  <xsl:template match="ltx:bibblock">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibitem/ltx:tags/ltx:tag[@role='title']">
    <article-title>
      <xsl:apply-templates/>
    </article-title>
  </xsl:template>

  <xsl:template match="ltx:bib-date[@role='publication']"> <!-- We are making the assumption that this contains only the year of publication -->
    <date>
      <year>                  <!--Otherwise, have to parse the date... -->
        <xsl:apply-templates/>
      </year>
    </date>
  </xsl:template>

  <xsl:template match="ltx:bib-note[@role='annotation']">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-organization">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-title">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-type">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-place">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bib-part[@role='number']">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:acknowledgements">
    <ack>
      <xsl:call-template name="require_p"/>
    </ack>
  </xsl:template>

  <!-- This is really sad; we should have preserved structured data from bibentry,
       rather than formatted data from bibitem -->
  <xsl:template match="ltx:bibitem/ltx:tags/ltx:tag[@role='authors']">
    <person-group person-group-type="author">
      <name>
        <!-- I will not do sophisticated handling trying to split this into several authors etc. -->
        <surname>
          <xsl:for-each select="str:tokenize(./text(),' ')">
            <xsl:if test="position()=last()">
              <xsl:value-of select="."/>
            </xsl:if>
          </xsl:for-each>
        </surname>
        <xsl:if test="contains(./text(),' ')">

          <given-names>
            <xsl:for-each select="str:tokenize(./text(),' ')">
              <xsl:if test="position()!=last()">
                <xsl:value-of select="."/><xsl:text> </xsl:text>
              </xsl:if>
            </xsl:for-each>
          </given-names>
        </xsl:if>
      </name>
    </person-group>
  </xsl:template>

  <xsl:template match="ltx:tag[@role='fullauthors']"/>
  <xsl:template match="ltx:bibitem/ltx:tags/ltx:text[@font='bold']">
    <bold><xsl:apply-templates/></bold>
  </xsl:template>

  <xsl:template match="ltx:tag[@role='refnum']"/>
  <xsl:template match="ltx:tag[@role='number']"/>

  <!-- End back section -->
  <!-- ======================================================================
       Start main section -->

  <xsl:template match="ltx:section">
    <sec>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </sec>
  </xsl:template>

  <xsl:template match="ltx:subsubsection">
    <sec>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </sec>
  </xsl:template>

  <xsl:template match="ltx:subsection">
    <sec>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </sec>
  </xsl:template>

  <xsl:template match="ltx:paragraph">
    <boxed-text>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </boxed-text>
  </xsl:template>

  <xsl:template match="ltx:paragraph/ltx:title">
    <caption>
      <xsl:call-template name="require_p"/>
    </caption>
  </xsl:template>

  <!-- a para with id, containing a single p w/o id; preserve the id -->
  <xsl:template match="ltx:para[@xml:id and ltx:p[not(@xml:id)] and count(*)=1]">
    <p>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates select="ltx:p/node()"/>
    </p>
  </xsl:template>

  <xsl:template match="ltx:p">
    <p>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </p>
  </xsl:template>

  <xsl:template match="ltx:note[@role='footnote']">
    <fn id="{generate-id(.)}">
      <xsl:call-template name="require_p"/>
    </fn>
  </xsl:template>

  <xsl:template match="ltx:inline-block">
    <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:verbatim">
    <preformat>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </preformat>
  </xsl:template>

  <xsl:template match="ltx:quote">
    <disp-quote>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </disp-quote>
  </xsl:template>

  <xsl:template match="ltx:itemize">
    <p>
      <list list-type="bullet">
        <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
        <xsl:apply-templates/>
      </list>
    </p>
  </xsl:template>

  <xsl:template match="ltx:enumerate">
    <p>
      <list list-type="order">
        <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
        <xsl:apply-templates/>
      </list>
    </p>
  </xsl:template>

  <xsl:template match="ltx:description">
    <list>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </list>
  </xsl:template>

  <xsl:template match="ltx:item">
    <list-item>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </list-item>
  </xsl:template>

  <!-- ======================================================================
       Equations and Math -->
  <xsl:template match="ltx:equationgroup">
    <disp-formula-group>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </disp-formula-group>
  </xsl:template>

  <xsl:template match="ltx:equation">
    <xsl:choose>
      <xsl:when test="count(ltx:Math | ltx:MathFork) > 1"> <!--Each needs disp-formula -->
        <disp-formula-group>
          <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
          <xsl:for-each select="ltx:Math | ltx:MathFork">
            <disp-formula>
              <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
              <xsl:apply-templates select="."/>
            </disp-formula>
          </xsl:for-each>
        </disp-formula-group>
      </xsl:when>
      <xsl:otherwise>
        <disp-formula>
          <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
          <xsl:apply-templates/>
        </disp-formula>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:Math[@mode='inline']">
    <inline-formula>
      <xsl:apply-templates select="m:math"/>
    </inline-formula>
  </xsl:template>

  <!-- caller (ltx:equation) will wrap disp-formula, as needed -->
  <xsl:template match="ltx:Math">
    <xsl:apply-templates select="m:math"/>
  </xsl:template>

  <xsl:template match="ltx:MathFork">
    <xsl:apply-templates select="ltx:Math[1]/m:math"/>
  </xsl:template>

  <!-- Copy MathML as is, but use mml as namespace prefix,
       since that's assumed by many non-XML aware JATS applications. -->
  <xsl:template match="m:*">
    <xsl:element name="mml:{local-name()}" namespace="http://www.w3.org/1998/Math/MathML">
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="m:math">
    <xsl:element name="mml:math" namespace="http://www.w3.org/1998/Math/MathML">
      <!-- Get the ltx:Math's @xml:id onto the mml:math -->
      <xsl:apply-templates select="../@xml:id" mode="copy-attribute"/>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================
       Figures, Tables, Floats, Theorems, etc -->

  <xsl:template match="ltx:caption">
    <caption>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates/>
      </xsl:if>
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates/>
        </p>
      </xsl:if>
    </caption>
  </xsl:template>

  <xsl:template match="ltx:toccaption"/>

  <xsl:template match="ltx:float">
    <boxed-text>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </boxed-text>
  </xsl:template>

  <xsl:template match="ltx:figure">
    <fig>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates select="ltx:caption"/>
      <xsl:apply-templates select="*[not(self::ltx:caption)]"/>
    </fig>
  </xsl:template>

  <xsl:template match="ltx:table">
    <table-wrap>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates select="ltx:caption"/>
      <xsl:apply-templates select="*[not(self::ltx:caption)]"/>
    </table-wrap>
  </xsl:template>

  <xsl:template match="ltx:tabular/*">
    <xsl:apply-imports>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
    </xsl:apply-imports>
  </xsl:template>

  <xsl:template match="ltx:tr">
    <xsl:apply-imports>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
    </xsl:apply-imports>
  </xsl:template>

  <xsl:template match="ltx:td">
    <xsl:apply-imports>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
    </xsl:apply-imports>
  </xsl:template>

  <xsl:template match="ltx:tabular">
    <xsl:if test="ancestor::ltx:table">
      <xsl:apply-imports>
        <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      </xsl:apply-imports>
    </xsl:if>
    <xsl:if test="not(ancestor::ltx:table)">
      <table-wrap>
        <xsl:apply-imports>
          <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
        </xsl:apply-imports>
      </table-wrap>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:graphics">
    <graphic xlink:href="{./@graphic}"/>
  </xsl:template>

  <xsl:template match="ltx:theorem">
    <statement>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </statement>
  </xsl:template>

  <xsl:template match="ltx:proof">
    <statement>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </statement>
  </xsl:template>

  <!-- ======================================================================
       Mid-level text -->

  <xsl:template match="ltx:note[@role='thanks']">
    <p>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </p>
  </xsl:template>

  <xsl:template match="ltx:p/ltx:note[@role='thanks']">
    <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:cite">
    <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibref">
    <xref ref-type="bibr" rid="{@idref}"><xsl:apply-templates/></xref>
  </xsl:template>

  <xsl:template match="ltx:ref[@idref]">
    <xref rid="{./@idref}">
      <xsl:apply-templates/>
    </xref>
  </xsl:template>

  <xsl:template match="ltx:ref[@labelref and not(@idref)]">
    <xref rid="{./@labelref}">
      <xsl:apply-templates/>
    </xref>
  </xsl:template>

  <xsl:template match="ltx:ref[not(./@idref or ./@labelref) and ./@href]">
    <ext-link xlink:href="{./@href}">
      <xsl:apply-templates/>
    </ext-link>
  </xsl:template>

  <xsl:template match="ltx:ref[parent::ltx:bibblock and @idref]">
    <xsl:apply-templates/> <!-- references are not allowed in mixed-citations -->
  </xsl:template>

  <!-- ======================================================================
       Low-level stuff -->

  <!-- Other font characteristics dont map to JATS:
       font: medium, upright, smallcaps, sanserif, typewriter,...
       fontsize
       xml:lang ??
  -->
  <xsl:template match="ltx:text">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:text[@class='ltx_phantom']"/>

  <xsl:template match="ltx:text[@font='bold']">
    <bold>
      <xsl:apply-templates/>
    </bold>
  </xsl:template>

  <xsl:template match="ltx:text[@font='italic']">
    <italic>
      <xsl:apply-templates/>
    </italic>
  </xsl:template>

  <xsl:template match="ltx:text[@framed='underline']">
    <underline>
      <xsl:apply-templates/>
    </underline>
  </xsl:template>

  <xsl:template match="ltx:emph">
    <italic>
      <xsl:apply-templates/>
    </italic>
  </xsl:template>

  <xsl:template match="ltx:sub">
    <sub>
      <xsl:apply-templates/>
    </sub>
  </xsl:template>

  <xsl:template match="ltx:sup">
    <sup>
      <xsl:apply-templates/>
    </sup>
  </xsl:template>

  <xsl:template match="ltx:rule">
    <hr/>
  </xsl:template>

  <xsl:template match="ltx:ERROR">
    An error in the conversion from LaTeX to XML has occurred here.
  </xsl:template>

  <xsl:template match="ltx:break"/>

</xsl:stylesheet>

