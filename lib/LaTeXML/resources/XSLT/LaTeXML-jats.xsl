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
   xmlns:xlink ="http://www.w3.org/1999/xlink"
   extension-element-prefixes="str"
   exclude-result-prefixes="ltx str m xlink">

  <xsl:import href="LaTeXML-tabular-xhtml.xsl"/>
  <xsl:import href="LaTeXML-common.xsl"/>

  <xsl:strip-space elements="*"/>
  <xsl:output method="xml" indent="yes"/>

  <xsl:variable name="footnotes" select="//ltx:note[@role='footnote']"/>
  <xsl:template name="add_classes"/>
  <xsl:param name="html_ns"></xsl:param>

  <xsl:template match="*">
    <xsl:message> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
        <xsl:for-each select="./@*">
          <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
        </xsl:for-each>
      </xsl:if>
      is currently not supported for the main body.
    </xsl:message>
    <xsl:comment> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
        <xsl:for-each select="./@*">
          <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
        </xsl:for-each>
      </xsl:if>
      is currently not supported for the main body.
    </xsl:comment>
  </xsl:template>

  <xsl:template match="*" mode="math">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="math"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*" mode="math">
    <xsl:attribute name="{local-name()}"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="@xml:id" mode="math">
    <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="*" mode="front">
    <xsl:message> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
        <xsl:for-each select="./@*">
          <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
        </xsl:for-each>
      </xsl:if>
      is currently not supported for the front matter.
    </xsl:message>
    <xsl:comment> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
        <xsl:for-each select="./@*">
          <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
        </xsl:for-each>
      </xsl:if>
      is currently not supported for the front matter.
    </xsl:comment>
  </xsl:template>

  <xsl:template match="*" mode="back">
    <xsl:message> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
        <xsl:for-each select="./@*">
          <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
        </xsl:for-each>
      </xsl:if>
      is currently not supported for the back matter.
    </xsl:message>
    <xsl:comment> The element <xsl:value-of select="name(.)"/> <xsl:if test="@*"> with attributes
        <xsl:for-each select="./@*">
          <xsl:value-of select="name(.)"/>=<xsl:value-of select="."/>
        </xsl:for-each>
      </xsl:if>
      is currently not supported for the back matter
    </xsl:comment>
  </xsl:template>

  <xsl:template match="ltx:ERROR">
    An error in the conversion from LaTeX to XML has occurred here.
  </xsl:template>

  <xsl:template match="ltx:ERROR" mode="front">
    An error in the conversion from LaTeX to XML has occurred here.
  </xsl:template>

  <xsl:template match="ltx:ERROR" mode="back">
    An error in the conversion from LaTeX to XML has occurred here.
  </xsl:template>

  <xsl:template match="ltx:document">
    <article>
      <front>
        <article-meta>
          <xsl:apply-templates select="ltx:title" mode="front"/>
          <contrib-group>
            <xsl:apply-templates select="ltx:creator[@role='author']" mode="front"/>
          </contrib-group>
          <xsl:apply-templates select="ltx:date[@role='creation']" mode="front"/>
          <xsl:apply-templates select="ltx:abstract" mode="front"/>
          <xsl:apply-templates select="ltx:keywords" mode="front"/>
          <xsl:apply-templates select="*[not(self::ltx:title or self::ltx:creator[@role='author'] or self::ltx:date[@role='creation'] or self::ltx:abstract or self::ltx:keywords)]" mode="front"/>
        </article-meta>
      </front>
      <body>
        <xsl:apply-templates select="@*|node()"/>
      </body>
      <back>
        <xsl:apply-templates select="@*|node()" mode="back"/>
        <app-group>
          <xsl:apply-templates select="//ltx:appendix" mode="app"/>
        </app-group>
      </back>

    </article>
  </xsl:template>

  <xsl:template match="ltx:para[not(ancestor::ltx:section or ancestor::ltx:appendix or ancestor::ltx:acknowledgements) and preceding::ltx:section]">  <!-- Is not allowed -->
    <xsl:comment><xsl:for-each select=".//text()"><xsl:value-of select="."/></xsl:for-each></xsl:comment> <!-- trying to provide the maximal information here -->
  </xsl:template>

  <xsl:template match="text()">
    <xsl:copy-of select="."/>
  </xsl:template>
  <!-- Front matter section -->
  <xsl:template match="ltx:creator[@role='author']" mode="front">
    <contrib contrib-type="author">
      <xsl:apply-templates mode="front"/>
    </contrib>
  </xsl:template>

  <xsl:template match="ltx:appendix" mode="app">
    <app>
      <xsl:apply-templates select="@*|node()"/>
    </app>
  </xsl:template>

  <xsl:template match="ltx:appendix/ltx:title">
    <title>
      <xsl:apply-templates select="@*|node()"/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:date[@role='creation']" mode="front">
    <pub-date><string-date><xsl:apply-templates select="@*|node()" /></string-date></pub-date>
  </xsl:template>

  <xsl:template match="ltx:creator" mode="front">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='affiliation']" mode="front">
    <aff><xsl:apply-templates select="@*|node()" /></aff>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='email']" mode="front">
    <email><xsl:apply-templates select="@*|node()" /></email>
  </xsl:template>
  <xsl:template match="ltx:personname" mode="front">
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

  <xsl:template match="ltx:text[@font='bold']" mode="front">
    <bold>
      <xsl:apply-templates mode="front" select="@*|node()"/>
    </bold>
  </xsl:template>
  <xsl:template match="ltx:abstract" mode="front">
    <abstract>
      <xsl:apply-templates select="@*|node()" />
    </abstract>
  </xsl:template>

  <xsl:template match="ltx:keywords" mode="front">
    <kwd-group>
      <xsl:for-each select="str:tokenize(./text(),',')">
        <kwd><xsl:value-of select="."/></kwd>
      </xsl:for-each>
    </kwd-group>
  </xsl:template>

  <xsl:template match="ltx:document/ltx:title" mode="front">
    <title-group>
      <article-title>
        <xsl:apply-templates select="@*|node()" />
      </article-title>
    </title-group>
  </xsl:template>

  <xsl:template match="ltx:equationgroup" mode="front">
    <disp-formula-group>
      <xsl:apply-templates select="@*|node()" mode="front"/>
    </disp-formula-group>
  </xsl:template>

  <xsl:template match="ltx:equationgroup/ltx:equation" mode="front">
    <disp-formula>
      <xsl:apply-templates select="@*" mode="front"/>
      <xsl:for-each select=".//m:math"><xsl:copy-of select="."/></xsl:for-each>
    </disp-formula>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='url']" mode="front">
    <xsl:apply-templates select="@*|node()" mode="front"/>
  </xsl:template>

  <xsl:template match="ltx:equation" mode="front">
    <p>
      <disp-formula>
        <xsl:apply-templates select="@*|node()"/>
      </disp-formula>
    </p>
  </xsl:template>

  <xsl:template match="ltx:Math[@mode='inline']" mode="front">
    <inline-formula>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select=".//m:math"><xsl:copy-of select="."/></xsl:for-each>
    </inline-formula>
  </xsl:template>

  <xsl:template match="ltx:caption" mode="front">
    <caption>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates select="@*|node()" mode="front"/>
      </xsl:if>
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@*|node()" mode="front"/>
        </p>
      </xsl:if>
    </caption>
  </xsl:template>

  <xsl:template match="ltx:caption" mode="back">
    <caption>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates select="@*|node()" mode="back"/>
      </xsl:if>
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@*|node()" mode="back"/>
        </p>
      </xsl:if>
    </caption>
  </xsl:template>

  <xsl:template match="ltx:caption">
    <caption>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates select="@*|node()"/>
      </xsl:if>
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@*|node()"/>
        </p>
      </xsl:if>
    </caption>
  </xsl:template>

  <xsl:template match="ltx:float" mode="front">
    <boxed-text>
      <xsl:apply-templates select="@*|node()" mode="front"/>
    </boxed-text>
  </xsl:template>

  <xsl:template match="ltx:paragraph">
    <boxed-text>
      <xsl:apply-templates select="@*|node()"/>
    </boxed-text>
  </xsl:template>

  <xsl:template match="ltx:paragraph/ltx:title">
    <caption>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates select="@*|node()"/>
      </xsl:if>
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@*|node()"/>
        </p>
      </xsl:if>
    </caption>
  </xsl:template>

  <xsl:template match="ltx:text[@font='italic']">
    <italic>
      <xsl:apply-templates select="@*|node()"/>
    </italic>
  </xsl:template>

  <xsl:template match="ltx:table" mode="front"/>
  <xsl:template match="ltx:abstract//ltx:table" mode="front">
    <xsl:message> There was a table in an abstract, deal with it </xsl:message> <!-- TODO if this actually happens, then deal with it -->
  </xsl:template>

  <!-- End front matter section -->
  <!-- Start back section -->
  <!-- This is essentially for bibliography and acknowledgements-->
  <!-- However I still need stuff to handle various other subcases that could come up in for example appendices or acknowledgements -->

  <xsl:template match="ltx:equationgroup" mode="back">
    <disp-formula-group>
      <xsl:apply-templates select="@*|node()" mode="back"/>
    </disp-formula-group>
  </xsl:template>

  <xsl:template match="ltx:equationgroup/ltx:equation" mode="back">
    <disp-formula>
      <xsl:for-each select=".//m:math"><xsl:copy-of select="."/></xsl:for-each>
    </disp-formula>
  </xsl:template>

  <xsl:template match="ltx:equation" mode="back">
    <p>
      <disp-formula>
        <xsl:for-each select=".//m:math"><xsl:copy-of select="."/></xsl:for-each>
      </disp-formula>
    </p>
  </xsl:template>

  <xsl:template match="ltx:Math[@mode='inline']" mode="back">
    <inline-formula>
      <xsl:for-each select=".//m:math"><xsl:copy-of select="."/></xsl:for-each>
    </inline-formula>
  </xsl:template>

  <xsl:template match="ltx:bibliography" mode="back">
    <ref-list>
      <xsl:apply-templates mode="back"/>
    </ref-list>
  </xsl:template>

  <xsl:template match="ltx:bibliography/ltx:title" mode="back">
    <title>
      <xsl:apply-templates select="@*|node()" />
    </title>
  </xsl:template>

  <xsl:template match="ltx:biblist" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibitem" mode="back">
    <ref>
      <xsl:if test="@xml:id">
        <xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute>
      </xsl:if>
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
<!--        <xsl:apply-templates select="node()" mode="back"/>-->
        <xsl:apply-templates mode="back"/>
      </mixed-citation>
    </ref>
  </xsl:template>

  <xsl:template match="ltx:tags" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:tag[@class='ltx_bib_type']" mode="back"/>
  <xsl:template match="ltx:tag[@role='key']" mode="back"/>

  <xsl:template match="ltx:bibblock//ltx:bib-part[@role='publisher']" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-note[@role='publication']" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>
  <xsl:template match="ltx:bibblock//ltx:bib-part[@role='series']" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-publisher" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-edition" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibitem/ltx:tags/ltx:tag[@role='year']" mode="back">
    <year>
      <xsl:apply-templates mode="back"/>
    </year>
  </xsl:template>

  <xsl:template match="ltx:bib-part[@role='volume']" mode="back">
    <volume>
      <xsl:apply-templates mode="back"/>
    </volume>
  </xsl:template>

  <xsl:template match="ltx:bib-part[@role='pages']" mode="back">
    <page-range>
      <xsl:apply-templates/>
    </page-range>
  </xsl:template>

  <xsl:template match="ltx:bibblock" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibitem/ltx:tags/ltx:tag[@role='title']" mode="back">
    <article-title>
      <xsl:apply-templates mode="back"/>
    </article-title>
  </xsl:template>

  <xsl:template match="ltx:bib-date[@role='publication']" mode="back"> <!-- We are making the assumption that this contains only the year of publication -->
    <date>
      <year>
        <xsl:apply-templates mode="back"/>
      </year>
    </date>
  </xsl:template>

  <xsl:template match="ltx:bib-note[@role='annotation']" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-organization" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-title" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-type" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bibblock//ltx:bib-place" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:bib-part[@role='number']" mode="back">
    <xsl:apply-templates mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:acknowledgements" mode="back">
    <ack>
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates mode="back" select="@*|node()"/>
        </p>
      </xsl:if>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates mode="back" select="@*|node()"/>
      </xsl:if>
    </ack>
  </xsl:template>

  <xsl:template match="ltx:text[@font='italic']" mode="back">
    <italic>
      <xsl:apply-templates select="@*|node()"/>
    </italic>
  </xsl:template>

  <xsl:template match="ltx:rule" mode="back">
    <hr/>
  </xsl:template>

  <xsl:template match="ltx:bibitem/ltx:tags/ltx:tag[@role='authors']" mode="back">
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
                <xsl:value-of select="."/>&#160;
              </xsl:if>
            </xsl:for-each>
          </given-names>
        </xsl:if>
      </name>
    </person-group>
  </xsl:template>

  <xsl:template match="ltx:tag[@role='fullauthors']" mode="back"/>
  <xsl:template match="ltx:bibitem/ltx:tags/ltx:text[@font='bold']" mode="back">
    <bold>
      <xsl:apply-templates mode="back" select="@*|node()"/>
    </bold>
  </xsl:template>
  <xsl:template match="ltx:tag[@role='refnum']" mode="back"/>
  <xsl:template match="ltx:tag[@role='number']" mode="back"/>

  <xsl:template match="ltx:table" mode="back"/>
  <xsl:template match="ltx:acknowledgements//ltx:table">
    <xsl:message> There's a table in the acknowledgements. Deal with it </xsl:message> <!-- TODO, actually do this if you ever see this -->
  </xsl:template>

  <!-- End back section -->
  <!-- Start main section -->

  <xsl:template match="ltx:note[@role='institutetext']" mode="back"/>
  <xsl:template match="ltx:note[@role='institutetext']"/>
  <xsl:template match="ltx:note[@role='institutetext']" mode="front"/>

  <xsl:template match="ltx:note[@role='footnote']">
    <fn id="{generate-id(.)}">
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@*|node()"/>
        </p>
      </xsl:if>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates select="@*|node()"/>
      </xsl:if>
    </fn>
  </xsl:template>

  <xsl:template match="ltx:para">
    <xsl:apply-templates select="@*|node()" />
  </xsl:template>

  <xsl:template match="ltx:equationgroup">
    <p>
      <disp-formula-group>
        <xsl:apply-templates select="@*|node()"/>
      </disp-formula-group>
    </p>
  </xsl:template>

  <xsl:template match="ltx:equation">
    <p>
      <disp-formula>
        <xsl:apply-templates select="@*"/>
        <xsl:for-each select=".//m:math"><xsl:apply-templates select="." mode="math"/></xsl:for-each>
      </disp-formula>
    </p>
  </xsl:template>

  <xsl:template match="ltx:equationgroup/ltx:equation">
    <disp-formula>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select=".//m:math"><xsl:apply-templates select="." mode="math"/></xsl:for-each>
    </disp-formula>
  </xsl:template>

  <xsl:template match="ltx:Math[@mode='inline']">
    <inline-formula>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select=".//m:math"><xsl:apply-templates select="." mode="math"/></xsl:for-each>
    </inline-formula>
  </xsl:template>

  <xsl:template match="ltx:inline-block">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:p">
    <p>
      <xsl:apply-templates select="@*|node()" />
    </p>
  </xsl:template>

  <xsl:template match="ltx:itemize">
    <p>
      <list list-type="bullet">
        <xsl:apply-templates select="@*|node()"/>
      </list>
    </p>
  </xsl:template>

  <xsl:template match="ltx:enumerate">
    <p>
      <list list-type="order">
        <xsl:apply-templates select="@*|node()"/>
      </list>
    </p>
  </xsl:template>

  <xsl:template match="ltx:item">
    <list-item>
      <xsl:apply-templates select="@*|node()"/>
    </list-item>
  </xsl:template>

  <xsl:template match="ltx:section">
    <sec>
      <xsl:apply-templates select="@*|node()" />
    </sec>
  </xsl:template>

  <xsl:template match="ltx:theorem">
    <statement>
      <xsl:apply-templates select="@*|node()"/>
    </statement>
  </xsl:template>

  <xsl:template match="ltx:theorem/ltx:title">
    <title>
      <xsl:apply-templates select="@*|node()"/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:proof">
    <statement>
      <xsl:apply-templates select="@*|node()"/>
    </statement>
  </xsl:template>

  <xsl:template match="ltx:proof/ltx:title">
    <title>
      <xsl:apply-templates select="@*|node()"/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='address']" mode="front">
    <address>
      <addr-line>
        <xsl:apply-templates select="@*|node()" mode="front"/>
      </addr-line>
    </address>
  </xsl:template>

  <xsl:template match="ltx:text[@class='ltx_phantom']" mode="front">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:subsubsection">
    <sec>
      <xsl:apply-templates select="@*|node()"/>
    </sec>
  </xsl:template>

  <xsl:template match="ltx:quote">
    <disp-quote>
      <xsl:apply-templates select="@*|node()"/>
    </disp-quote>
  </xsl:template>

  <xsl:template match="ltx:section/ltx:title">
    <title>
      <xsl:apply-templates select="@*|node()"/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:float">
    <boxed-text>
      <xsl:apply-templates select="@*|node()"/>
    </boxed-text>
  </xsl:template>

  <xsl:template match="ltx:subsection/ltx:title">
    <title>
      <xsl:apply-templates select="@*|node()"/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:subsubsection/ltx:title">
    <title>
      <xsl:apply-templates select="@*|node()"/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:subsection">
    <sec>
      <xsl:apply-templates select="@*|node()"/>
    </sec>
  </xsl:template>

  <xsl:template match="ltx:figure/ltx:caption">
    <caption>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates select="@*|node()"/>
      </xsl:if>
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@*|node()"/>
        </p>
      </xsl:if>
    </caption>
  </xsl:template>

  <xsl:template match="ltx:figure">
    <fig>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="ltx:caption"/>
      <xsl:apply-templates select="*[not(self::ltx:caption)]"/>
    </fig>
  </xsl:template>

  <xsl:template match="ltx:table">
    <table-wrap>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="ltx:caption"/>
      <xsl:apply-templates select="*[not(self::ltx:caption)]"/>
    </table-wrap>
  </xsl:template>

  <xsl:template match="ltx:tabular/*">
    <xsl:apply-imports>
      <xsl:apply-templates select="@*"/>
    </xsl:apply-imports>
  </xsl:template>

  <xsl:template match="ltx:tr">
    <xsl:apply-imports>
      <xsl:apply-templates select="@*"/>
    </xsl:apply-imports>
  </xsl:template>

  <xsl:template match="ltx:td">
    <xsl:apply-imports>
      <xsl:apply-templates select="@*"/>
    </xsl:apply-imports>
  </xsl:template>

  <xsl:template match="ltx:tabular">
    <xsl:if test="ancestor::ltx:table">
      <xsl:apply-imports>
        <xsl:apply-templates select="@*"/>
      </xsl:apply-imports>
    </xsl:if>
    <xsl:if test="not(ancestor::ltx:table)">
      <table-wrap>
        <xsl:apply-imports>
          <xsl:apply-templates select="@*"/>
        </xsl:apply-imports>
      </table-wrap>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:table/ltx:caption">
    <caption>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates select="@*|node()"/>
      </xsl:if>
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@*|node()"/>
        </p>
      </xsl:if>
    </caption>
  </xsl:template>

  <xsl:template match="ltx:graphics">
    <graphic xlink:href="{./@graphic}"> <!-- Probably could have made this an empty element, but I just wanted to go sure -->
      <xsl:apply-templates select="@*|node()"/>
    </graphic>
  </xsl:template>
  <xsl:template match="ltx:text[@class='ltx_ref_tag']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:note[@role='thanks']">
    <p>
      <xsl:apply-templates select="@*|node()" />
    </p>
  </xsl:template>

  <xsl:template match="ltx:p/ltx:note[@role='thanks']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:section/ltx:title">
    <title>
      <xsl:apply-templates select="@*|node()" />
    </title>
  </xsl:template>

  <xsl:template match="ltx:cite">
    <xsl:if test="./ltx:ref/@idref">
      <xref ref-type="bibr" rid="{./ltx:ref/@idref}"><xsl:apply-templates select="@*|node()" /></xref>
    </xsl:if>
    <xsl:if test="./ltx:bibref/@bibrefs">
      <xsl:for-each select="str:tokenize(./ltx:bibref/@bibrefs,./ltx:bibref/@yyseparator)">
        <xref ref-type="bibr" rid="{.}"><xsl:apply-templates select="@*|node()"/></xref>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:bibref">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:ref[@idref]">
    <xref rid="{./@idref}">
      <xsl:apply-templates select="@*|node()"/>
    </xref>
  </xsl:template>

  <xsl:template match="ltx:ref[@idref and ancestor::ltx:cite]">
    <xsl:apply-templates select="@*|node()" />
  </xsl:template>

  <xsl:template match="ltx:ref[@labelref and not(@idref)]">
    <xref rid="{./@labelref}">
      <xsl:apply-templates select="@*|node()"/>
    </xref>
  </xsl:template>

  <xsl:template match="ltx:ref[@class='ltx_url']">
    <ext-link xlink:href="{./href}">
      <xsl:apply-templates select="@*|node()"/>
    </ext-link>
  </xsl:template>

  <xsl:template match="ltx:ref[@class='ltx_url']" mode="front">
    <ext-link xlink:href="{./href}">
      <xsl:apply-templates select="@*|node()" mode="front"/>
    </ext-link>
  </xsl:template>

  <xsl:template match="ltx:ref[@class='ltx_url']" mode="back">
    <ext-link xlink:href="{./href}">
      <xsl:apply-templates select="@*|node()" mode="back"/>
    </ext-link>
  </xsl:template>

  <xsl:template match="ltx:ref[not(./@idref or ./@labelref) and ./@href]">
    <ext-link xlink:href="{./href}">
      <xsl:apply-templates select="@*|node()"/>
    </ext-link>
  </xsl:template>

  <xsl:template match="ltx:ref[not(./@idref or ./@labelref) and ./@href]" mode="front">
    <ext-link xlink:href="{./href}">
      <xsl:apply-templates select="@*|node()"/>
    </ext-link>
  </xsl:template>

  <xsl:template match="ltx:ref[not(./@idref or ./@labelref) and ./@href]" mode="back">
    <ext-link xlink:href="{./href}">
      <xsl:apply-templates select="@*|node()"/>
    </ext-link>
  </xsl:template>

  <xsl:template match="ltx:ref[@idref]" mode="back">
    <xref rid="{./@idref}">
      <xsl:apply-templates mode="back"/>
    </xref>
  </xsl:template>

  <xsl:template match="ltx:ref[ancestor::ltx:bibblock]" mode="back">
    <xsl:apply-templates mode="back"/> <!-- references are not allowed in mixed-citations -->
  </xsl:template>

  <xsl:template match="ltx:ref[@idref]" mode="front">
    <xref rid="{./@idref}">
      <xsl:apply-templates mode="front"/>
    </xref>
  </xsl:template>

  <xsl:template match="ltx:float" mode="back">
    <boxed-text>
      <xsl:apply-templates select="@*|node()" mode="back"/>
    </boxed-text>
  </xsl:template>

  <xsl:template match="ltx:titlepage">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:description">
    <list>
      <xsl:apply-templates select="@*|node()"/>
    </list>
  </xsl:template>

  <xsl:template match="ltx:verbatim">
    <preformat>
      <xsl:apply-templates select="@*|node()"/>
    </preformat>
  </xsl:template>

  <!-- End body section -->
  <xsl:template match="ltx:document/ltx:title"/>
  <!-- This section is for elements that we aren't doing anything with and just removing from the document -->
  <xsl:template match="ltx:resource[@type='text/css']"/>
  <xsl:template match="ltx:creator[@role='author']"/>
  <xsl:template match="ltx:resource[@type='text/css']" mode="front"/>
  <xsl:template match="ltx:abstract"/>
  <xsl:template match="ltx:keywords"/>
  <xsl:template match="ltx:note[@role='thanks']" mode="front"/>
  <xsl:template match="ltx:contact[@role='thanks']" mode="front"/>
  <xsl:template match="ltx:section" mode="front"/>
  <xsl:template match="ltx:acknowledgements"/>
  <xsl:template match="ltx:acknowledgements" mode="front"/>
  <xsl:template match="ltx:bibliography"/>
  <xsl:template match="ltx:bibliography" mode="front"/>
  <xsl:template match="ltx:date[@role='creation']"/>
  <xsl:template match="ltx:tags"/>
  <xsl:template match="ltx:tag"/>
  <xsl:template match="ltx:break"/> <!-- Break isn't really supposed to be used -->
  <xsl:template match="ltx:resource[@type='text/css']" mode="back"/>
  <xsl:template match="ltx:creator[@role='author']" mode="back"/>
  <xsl:template match="ltx:abstract" mode="back"/>
  <xsl:template match="ltx:keywords" mode="back"/>
  <xsl:template match="ltx:note[@role='thanks']" mode="back"/>
  <xsl:template match="ltx:section" mode="back"/>
  <xsl:template match="ltx:date[@role='creation']" mode="back"/>
  <xsl:template match="ltx:document/ltx:title" mode="back"/>
  <xsl:template match="ltx:para" mode="front"/>
  <xsl:template match="ltx:para" mode="back"/>
  <xsl:template match="ltx:toccaption"/>
  <xsl:template match="ltx:classification"/>
  <xsl:template match="ltx:classification" mode="back"/>
  <xsl:template match="ltx:classification" mode="front"/>
  <xsl:template match="ltx:note[@role='slugcomment']"/>
  <xsl:template match="ltx:note[@role='slugcomment']" mode="front"/>
  <xsl:template match="ltx:note[@role='slugcomment']" mode="back"/>
  <xsl:template match="ltx:pagination"/>
  <xsl:template match="ltx:pagination" mode="front"/>
  <xsl:template match="ltx:pagination" mode="back"/>
  <xsl:template match="ltx:toctitle"/>
  <xsl:template match="ltx:toctitle" mode="front"/>
  <xsl:template match="ltx:toctitle" mode="back"/>
  <xsl:template match="ltx:appendix" mode="front"/>
  <xsl:template match="ltx:appendix" mode="back"/>
  <xsl:template match="ltx:appendix"/>
  <xsl:template match="ltx:contact[@role='emailmark']" mode="front"/>
  <xsl:template match="ltx:contact[@role='emailmark']" mode="back"/>
  <xsl:template match="ltx:contact[@role='emailmark']"/>
  <xsl:template match="ltx:contact[@role='institutemark']" mode="front"/>
  <xsl:template match="ltx:contact[@role='institutemark']" mode="back"/>
  <xsl:template match="ltx:contact[@role='institutemark']"/>
  <xsl:template match="ltx:creator" mode="back"/>
  <xsl:template match="ltx:creator"/>
  <xsl:template match="ltx:contact[@role='affiliation']"/>
  <xsl:template match="ltx:titlepage" mode="front"/>
  <xsl:template match="ltx:titlepage" mode="back"/>
  <xsl:template match="ltx:break" mode="front"/>
  <xsl:template match="ltx:figure" mode="front"/>
  <xsl:template match="ltx:figure" mode="back"/>
  <xsl:template match="ltx:break" mode="back"/>
  <xsl:template match="ltx:contact[@role='dedicatory']" mode="front"/>
  <xsl:template match="ltx:contact[@role='dedicatory']" mode="back"/>
  <xsl:template match="ltx:contact[@role='dedicatory']"/>
  <xsl:template match="ltx:TOC"/>
  <xsl:template match="ltx:TOC" mode="front"/>
  <xsl:template match="ltx:TOC" mode="back"/>

  <xsl:template match="ltx:abstract/ltx:figure" mode="front">
    <xsl:message>figure in an abstract, fix this </xsl:message> <!-- TODO actualy fix it if it happens -->
  </xsl:template>
  <!-- hackish stuff for references -->

  <xsl:template match="ltx:para/@xml:id"/>
  <xsl:template match="ltx:para[@xml:id]/ltx:p">
    <xsl:choose>
      <xsl:when test="not(preceding-sibling::ltx:p)">
        <p id="{../@xml:id}">
          <xsl:apply-templates select="@*|node()"/>
        </p>
      </xsl:when>
      <xsl:otherwise>
        <p>
          <xsl:apply-templates select="@*|node()"/>
        </p>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:template>
  <xsl:template match="ltx:document/@xml:id"/>
  <xsl:template match="ltx:document/@xml:id" mode="front"/>
  <xsl:template match="ltx:document/@xml:id" mode="back"/>
  <xsl:template match="ltx:document/@labels"/>
  <xsl:template match="@xml:id">
    <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute> <!-- If everything has an id at the appropriate place now, this never ought to run into issues -->
  </xsl:template>

  <xsl:template match="ltx:para/@xml:id" mode="front"/>
  <xsl:template match="ltx:para[@xml:id]/ltx:p" mode="front">
    <p id="{../@xml:id}">
      <xsl:apply-templates select="@*|node()" mode="back"/>
    </p>
  </xsl:template>
  <xsl:template match="@xml:id" mode="front">
    <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="ltx:para/@xml:id" mode="back"/>
  <xsl:template match="ltx:para[@xml:id]/ltx:p" mode="back">
    <p id="{../@xml:id}">
      <xsl:apply-templates select="@*|node()" mode="back"/>
    </p>
  </xsl:template>
  <xsl:template match="@xml:id" mode="back">
    <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="@*"/>
  <xsl:template match="@*" mode="back"/>
  <xsl:template match="@*" mode="front"/>
  <!-- end of hackish references stuff -->
  <!-- font section -->
  <xsl:template match="ltx:text[@font='bold']">
    <bold>
      <xsl:apply-templates select="@*|node()"/>
    </bold>
  </xsl:template>

  <xsl:template match="ltx:text[@font='italic']">
    <italic>
      <xsl:apply-templates select="@*|node()"/>
    </italic>
  </xsl:template>

  <xsl:template match="ltx:text[@font='medium']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='medium']" mode="back">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='medium']" mode="front">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@fontsize='90%']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@fontsize='80%']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='upright']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='smallcaps']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='smallcaps']" mode="front">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='smallcaps']" mode="back">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@class='ltx_markedasmath']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='sansserif']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='sansserif']" mode="front">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='sansserif']" mode="back">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='serif']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='serif']" mode="front">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='serif']" mode="back">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='typewriter']">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='typewriter']" mode="front">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@font='typewriter']" mode="back">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@xml:lang]">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@xml:lang]" mode="front">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@xml:lang]" mode="back">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@framed='underline']">
    <underline>
      <xsl:apply-templates select="@*|node()"/>
    </underline>
  </xsl:template>

  <xsl:template match="ltx:text[@framed='underline']" mode="front">
    <underline>
      <xsl:apply-templates select="@*|node()" mode="front"/>
    </underline>
  </xsl:template>

  <xsl:template match="ltx:text[@framed='underline']" mode="back">
    <underline>
      <xsl:apply-templates select="@*|node()" mode="back"/>
    </underline>
  </xsl:template>

  <xsl:template match="ltx:text[@class]">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text[@class]" mode="front">
    <xsl:apply-templates select="@*|node()" mode="front"/>
  </xsl:template>

  <xsl:template match="ltx:text[@class]" mode="back">
    <xsl:apply-templates select="@*|node()" mode="back"/>
  </xsl:template>

  <xsl:template match="ltx:text">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text" mode="back">
    <xsl:apply-templates mode="back" select="@*|node()"/>
  </xsl:template>

  <xsl:template match="ltx:text" mode="front">
    <xsl:apply-templates mode="back" select="@*|node()"/>
  </xsl:template>

  <!-- text formatting -->

  <xsl:template match="ltx:emph">
    <italic>
      <xsl:apply-templates select="@*|node()"/>
    </italic>
  </xsl:template>

  <xsl:template match="ltx:emph" mode="front">
    <italic>
      <xsl:apply-templates select="@*|node()" mode="front"/>
    </italic>
  </xsl:template>

  <xsl:template match="ltx:emph" mode="back">
    <italic>
      <xsl:apply-templates select="@*|node()" mode="back"/>
    </italic>
  </xsl:template>

  <xsl:template match="ltx:sub">
    <sub>
      <xsl:apply-templates select="@*|node()"/>
    </sub>
  </xsl:template>

  <xsl:template match="ltx:sub" mode="front">
    <sub>
      <xsl:apply-templates select="@*|node()" mode="front"/>
    </sub>
  </xsl:template>

  <xsl:template match="ltx:sub" mode="back">
    <sub>
      <xsl:apply-templates select="@*|node()" mode="back"/>
    </sub>
  </xsl:template>

  <xsl:template match="ltx:sup">
    <sup>
      <xsl:apply-templates select="@*|node()"/>
    </sup>
  </xsl:template>

  <xsl:template match="ltx:sup" mode="front">
    <sup>
      <xsl:apply-templates select="@*|node()" mode="front"/>
    </sup>
  </xsl:template>

  <xsl:template match="ltx:sup" mode="back">
    <sup>
      <xsl:apply-templates select="@*|node()" mode="back"/>
    </sup>
  </xsl:template>

  <!-- Templates to make things more convenient -->
</xsl:stylesheet>

