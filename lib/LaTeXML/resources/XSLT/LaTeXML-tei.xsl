<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet
    version     ="1.0"
    xmlns:xsl   ="http://www.w3.org/1999/XSL/Transform"
    xmlns       ="http://www.tei-c.org/ns/1.0"
    xmlns:ltx   ="http://dlmf.nist.gov/LaTeXML"
    xmlns:str   ="http://exslt.org/strings"
    xmlns:m     ="http://www.w3.org/1998/Math/MathML"
    xmlns:svg   ="http://www.w3.org/2000/svg"
    xmlns:xlink ="http://www.w3.org/1999/xlink"
    extension-element-prefixes="str"
    exclude-result-prefixes="ltx str m svg xlink">

  <!-- Possibly useful validator:
       https://teibyexample.org/tools/TBEvalidator.htm
  -->

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
  <xsl:strip-space elements="ltx:Math"/>

  <xsl:output
      method = "xml"
      indent = "yes"
      encoding = 'utf-8'/>

  <xsl:variable name="footnotes" select="//ltx:note[@role='footnote']"/>
  <xsl:template name="add_classes"/>
  <xsl:param name="html_ns"></xsl:param>
  <xsl:param name="USE_XMLID">true</xsl:param>

  <!-- ======================================================================
       Basic Document structure -->

  <xsl:template match="ltx:document">
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <xsl:call-template name="header"/>
      <text>
        <body>
          <xsl:apply-templates select="*[
                                       not(self::ltx:title or self::ltx:creator or self::ltx:date or self::ltx:abstract or self::ltx:keywords or self::ltx:classification)
                                       and not(self::ltx:acknowledgements or self::ltx:bibliography)
                                       and not(self::ltx:appendix)]"/>
        </body>
        <back>
          <xsl:apply-templates select="ltx:acknowledgements"/>
          <xsl:apply-templates select="ltx:bibliography"/>
          <xsl:apply-templates select="//ltx:appendix"/>
        </back>
      </text>
    </TEI>
  </xsl:template>

  <xsl:template match="ltx:para[not(ancestor::ltx:section or ancestor::ltx:appendix or ancestor::ltx:acknowledgements) and preceding::ltx:section]">  <!-- Is not allowed -->
    <xsl:comment><xsl:for-each select=".//text()"><xsl:value-of select="."/></xsl:for-each></xsl:comment> <!-- trying to provide the maximal information here -->
  </xsl:template>

  <!-- ======================================================================
       Some standard preliminaries -->

  <!-- In general, ltx:title maps to head -->
  <xsl:template match="ltx:title">
    <head>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </head>
  </xsl:template>

  <xsl:template match="ltx:toctitle"/>
  <xsl:template match="ltx:tags"/>
  <xsl:template match="ltx:tag"/>
  <xsl:template match="ltx:resource"/>

  <!-- ======================================================================
       Front matter section -->

  <xsl:template name="header">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <xsl:apply-templates select="ltx:title"/>
          <xsl:apply-templates select="ltx:creator[@role='author']"/>
          <xsl:apply-templates select="ltx:creator[@role='edtior']"/>
        </titleStmt>
        <publicationStmt>
          <publisher></publisher>
        </publicationStmt>
        <sourceDesc>
          <biblStruct>
            <analytic>
              <!-- All authors are included here -->
              <xsl:apply-templates select="ltx:creator[@role='author']"/>
                <!-- Title information related to the paper goes here -->
                <xsl:apply-templates select="ltx:title"/>
              </analytic>
              <monogr>
                <imprint>
                  <xsl:apply-templates select="ltx:date"/>
                </imprint>
              </monogr>
            </biblStruct>
          </sourceDesc>
        </fileDesc>
        <profileDesc>
          <xsl:apply-templates select="ltx:abstract"/>
          <xsl:if test="ltx:keywords or ltx:classification">
            <textClass>
              <xsl:apply-templates select="ltx:keywords"/>
              <xsl:apply-templates select="ltx:classification"/>
            </textClass>
          </xsl:if>
        </profileDesc>
      </teiHeader>
  </xsl:template>

  <xsl:template match="ltx:document/ltx:title">
    <title level="a" type="main">
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:titlepage">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:creator[@role='author']">
    <author>
      <xsl:apply-templates/>
    </author>
  </xsl:template>

  <xsl:template match="ltx:creator[@role='editor']">
    <editor>
      <xsl:apply-templates/>
    </editor>
  </xsl:template>

  <xsl:template match="ltx:date[@role='creation']">
    <date>
      <xsl:for-each select="str:tokenize(./text(),' ')">
        <xsl:if test="position()=last()">
          <xsl:value-of select="."/>
        </xsl:if>
      </xsl:for-each>
    </date>
  </xsl:template>

  <!-- WHich of these is right?-->
  <xsl:template match="ltx:date[@role='creation']">
    <date type="published">
      <xsl:attribute name="when">
        <xsl:for-each select="str:tokenize(./text(),' ')">
          <xsl:if test="position()=last()">
            <xsl:value-of select="."/>
          </xsl:if>
        </xsl:for-each>
      </xsl:attribute>
    </date>
  </xsl:template>

  <xsl:template match="ltx:contact"/> <!--Unless otherwise -->

  <xsl:template match="ltx:contact[@role='affiliation']">
    <affiliation><xsl:apply-templates/></affiliation>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='address']">
    <address>
      <addrLine>
        <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
        <xsl:apply-templates/>
      </addrLine>
    </address>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='email']">
    <email><xsl:apply-templates /></email>
  </xsl:template>

  <xsl:template match="ltx:contact[@role='url']">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:note[@role='institutetext']"/>

  <xsl:template match="ltx:note[@role='thanks']">
    <p>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </p>
  </xsl:template>

  <xsl:template match="ltx:p/ltx:note[@role='thanks']">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:personname">
    <persName>
      <surname>
        <xsl:for-each select="str:tokenize(./text(),' ')">
          <xsl:if test="position()=last()">
            <xsl:value-of select="."/>
          </xsl:if>
        </xsl:for-each>
      </surname>
      <forename>
        <xsl:for-each select="str:tokenize(./text(),' ')">
          <xsl:if test="position()!=last()">
            <xsl:value-of select="."/>
          </xsl:if>
        </xsl:for-each>
      </forename>
    </persName>
  </xsl:template>

  <xsl:template match="ltx:abstract">
    <abstract>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </abstract>
  </xsl:template>

  <xsl:template match="ltx:keywords">
    <keywords>
      <list>
      <xsl:for-each select="str:tokenize(./text(),',')">
        <item><xsl:value-of select="."/></item>
      </xsl:for-each>
      </list>
    </keywords>
  </xsl:template>

  <xsl:template match="ltx:classification">
    <classCode scheme="{@scheme}"><xsl:apply-templates/></classCode>
  </xsl:template>

  <!-- ======================================================================
       back section -->
  <!-- This is essentially for bibliography and acknowledgements-->
  <!-- However I still need stuff to handle various other subcases that could come up in for example appendices or acknowledgements -->

  <xsl:template match="ltx:appendix">
    <app>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </app>
  </xsl:template>

  <xsl:template match="ltx:bibliography">
    <div type="references">
      <listBibl>
        <xsl:apply-templates/>
      </listBibl>
    </div>
  </xsl:template>

  <xsl:template match="ltx:biblist">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibitem">
    <bibl>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <!-- Getting the reference type into the reference, if possible -->
      <xsl:if test="./ltx:tags/ltx:tag[@class='ltx_bib_type']">
        <xsl:attribute name="type"> <xsl:value-of select="./ltx:tags/ltx:tag[@class='ltx_bib_type']/text()"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="node()"/>
    </bibl>
  </xsl:template>

  <xsl:template match="ltx:tags">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:tags/ltx:tag[@class='ltx_bib_type']"/>
  <xsl:template match="ltx:tags/ltx:tag[@role='key']"/>

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

<!--
  <xsl:template match="ltx:tags/ltx:tag[@role='year']">
    <year>
      <xsl:apply-templates/>
    </year>
  </xsl:template>
-->
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

  <xsl:template match="ltx:tags/ltx:tag[@role='title']">
    <title>
      <xsl:apply-templates/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:bib-date[@role='publication']"> <!-- We are making the assumption that this contains only the year of publication -->
    <date>
      <xsl:apply-templates/>
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

  <xsl:template match="ltx:emph">
    <hi rend="italic">
      <xsl:apply-templates/>
    </hi>
  </xsl:template>

  <xsl:template match="ltx:acknowledgements">
    <div type="acknowledgements">
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
          <xsl:apply-templates/>
        </p>
      </xsl:if>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
        <xsl:apply-templates/>
      </xsl:if>
    </div>
  </xsl:template>

  <!-- This is really sad; we should have preserved structured data from bibentry,
       rather than formatted data from bibitem -->
<!--
  <xsl:template match="ltx:tags/ltx:tag[@role='authors']">
    <person-group person-group-type="author">
      <name>
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
-->

  <xsl:template match="ltx:tags/ltx:tag[@role='authors']">
    <!-- Should split into separate authors, but... -->
    <author><xsl:apply-templates/></author>
  </xsl:template>

  <xsl:template match="ltx:tags/ltx:tag[@role='fullauthors']"/>
  <xsl:template match="ltx:tags/ltx:tag[@role='refnum']"/>
  <xsl:template match="ltx:tags/ltx:tag[@role='number']"/>

  <xsl:template match="ltx:table"/>
  <xsl:template match="ltx:acknowledgements//ltx:table">
    <xsl:message> There's a table in the acknowledgements. Deal with it </xsl:message> <!-- TODO, actually do this if you ever see this -->
  </xsl:template>

  <!-- ======================================================================
       Start main section -->

  <xsl:template match="ltx:tag[@role='refnum']" mode="copy-refnum">
    <xsl:attribute name="n">
      <xsl:value-of select="text()"/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="ltx:section">
    <div type="section">
      <xsl:apply-templates select="ltx:tags/ltx:tag[@role='refnum']" mode="copy-refnum"/>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>

    </div>
  </xsl:template>

  <xsl:template match="ltx:subsection">
    <div type="subsection">
      <xsl:apply-templates select="ltx:tags/ltx:tag[@role='refnum']" mode="copy-refnum"/>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:subsubsection">
    <div type="subsubsection">
      <xsl:apply-templates select="ltx:tags/ltx:tag[@role='refnum']" mode="copy-refnum"/>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:paragraph">
    <div type="paragraph">
      <xsl:apply-templates select="ltx:tags/ltx:tag[@role='refnum']" mode="copy-refnum"/>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:note[@role='footnote']">
    <note place="bottom">
      <xsl:if test="not(./ltx:p)">
        <p>
          <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
          <xsl:apply-templates/>
        </p>
      </xsl:if>
      <xsl:if test="./ltx:p">
        <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
        <xsl:apply-templates/>
      </xsl:if>
    </note>
  </xsl:template>

  <xsl:template match="ltx:para">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:para/@xml:id"/>

  <xsl:template match="ltx:para[@xml:id]/ltx:p">
    <xsl:choose>
      <xsl:when test="not(preceding-sibling::ltx:p)">
        <p>
          <xsl:attribute name="xml:id"><xsl:value-of select="../@xml:id"/></xsl:attribute>
          <xsl:apply-templates/>
        </p>
      </xsl:when>
      <xsl:otherwise>
        <p>
          <xsl:attribute name="xml:id"><xsl:value-of select="../@xml:id"/></xsl:attribute>
          <xsl:apply-templates/>
        </p>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:template>

  <xsl:template match="ltx:p">
    <p>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </p>
  </xsl:template>

  <xsl:template match="ltx:inline-block">
    <figure>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </figure>
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
      <list rend="bulleted">
        <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
        <xsl:apply-templates/>
      </list>
    </p>
  </xsl:template>

  <xsl:template match="ltx:enumerate">
    <p>
      <list rend="numbered">
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
    <xsl:if test="ltx:tags/ltx:tag[not(@role)]">
      <label><xsl:value-of select="ltx:tags/ltx:tag[not(@role)]"/></label>
    </xsl:if>
    <item>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </item>
  </xsl:template>

  <!-- ======================================================================
       Equations and Math -->

  <xsl:template match="ltx:equationgroup">
    <p>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </p>
  </xsl:template>

  <xsl:template match="ltx:equationgroup/ltx:equation">
    <formula notation="mathml" >
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </formula>
  </xsl:template>

  <xsl:template match="ltx:equation">
    <p>
      <formula notation="mathml" >
        <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
        <xsl:apply-templates/>
      </formula>
    </p>
  </xsl:template>

  <xsl:template match="ltx:Math[@mode='inline']">
    <formula notation="mathml" rend="inline">
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates select="m:math"/>
    </formula>
  </xsl:template>

  <xsl:template match="m:*">
    <xsl:element name="m:{local-name()}" namespace="http://www.w3.org/1998/Math/MathML">
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!-- caller (ltx:equation) will wrap formula, as needed -->
  <xsl:template match="ltx:MathFork">
    <xsl:apply-templates select="ltx:Math[1]/m:math"/>
  </xsl:template>

  <xsl:template match="ltx:Math">
    <xsl:apply-templates select="m:math"/>
  </xsl:template>

  <!-- ======================================================================
       Figures, Tables, Floats, Theorems, etc -->

  <xsl:template match="ltx:caption">
    <head>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </head>
  </xsl:template>

  <xsl:template match="ltx:toccaption"/>

  <xsl:template match="ltx:float">
    <boxed-text>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </boxed-text>
  </xsl:template>

  <xsl:template match="ltx:figure">
    <figure>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates select="ltx:caption"/>
      <xsl:apply-templates select="*[not(self::ltx:caption)]"/>
    </figure>
  </xsl:template>

  <xsl:template match="ltx:table">
    <table>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates select="ltx:caption"/>
      <xsl:apply-templates select="*[not(self::ltx:caption)]"/>
    </table>
  </xsl:template>

  <xsl:template match="ltx:tabular">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:thead | ltx:tbody | ltx:tfoot">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:tr">
    <row>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </row>
  </xsl:template>

  <xsl:template match="ltx:td">
    <cell>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </cell>
  </xsl:template>

  <xsl:template match="ltx:graphics">
    <graphic url="{./@graphic}"/>
  </xsl:template>

  <xsl:template match="ltx:theorem">
    <note>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </note>
  </xsl:template>

  <xsl:template match="ltx:theorem/ltx:title">
    <title>
      <xsl:apply-templates/>
    </title>
  </xsl:template>

  <xsl:template match="ltx:proof">
    <note>
      <xsl:apply-templates select="@xml:id" mode="copy-attribute"/>
      <xsl:apply-templates/>
    </note>
  </xsl:template>

  <xsl:template match="ltx:proof/ltx:title">
    <title>
      <xsl:apply-templates/>
    </title>
  </xsl:template>

  <!-- ======================================================================
       Mid-level text -->

  <xsl:template match="ltx:cite">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:bibref">
    <ref type="bibr" target="{@idref}"><xsl:apply-templates/></ref>
  </xsl:template>

  <xsl:template match="ltx:ref[@idref]">
    <ref target="{./@idref}">
      <xsl:apply-templates/>
    </ref>
  </xsl:template>

  <xsl:template match="ltx:ref[@idref and ancestor::ltx:cite]">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:ref[@labelref and not(@idref)]">
    <ref target="{./@labelref}">
      <xsl:apply-templates/>
    </ref>
  </xsl:template>

  <xsl:template match="ltx:ref[@class='ltx_url']">
    <ext-link xlink:href="{./href}">
      <xsl:apply-templates/>
    </ext-link>
  </xsl:template>

  <xsl:template match="ltx:ref[not(./@idref or ./@labelref) and ./@href]">
    <ext-link xlink:href="{./href}">
      <xsl:apply-templates/>
    </ext-link>
  </xsl:template>

  <xsl:template match="ltx:ref[@idref]">
    <ref target="{./@idref}">
      <xsl:apply-templates/>
    </ref>
  </xsl:template>

  <xsl:template match="ltx:ref[ancestor::ltx:bibblock]">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:ref[@idref]">
    <ref target="{./@idref}">
      <xsl:apply-templates/>
    </ref>
  </xsl:template>

  <!-- ======================================================================
       Low-level  section -->

  <!-- Other font characteristics dont map to TEI:
       font: medium, upright, smallcaps, sanserif, typewriter,...
       fontsize
       xml:lang ??
       ltx:sub, ltx:sup ?
  -->

  <xsl:template match="ltx:text">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="ltx:text[@class='ltx_phantom']"/>

  <xsl:template match="ltx:text[@font='bold']">
    <hi rend="bold">
      <xsl:apply-templates/>
    </hi>
  </xsl:template>

  <xsl:template match="ltx:text[@font='italic']">
    <hi rend="italic">
      <xsl:apply-templates/>
    </hi>
  </xsl:template>

  <xsl:template match="ltx:emph">
    <hi rend="italic">
      <xsl:apply-templates/>
    </hi>
  </xsl:template>

  <xsl:template match="ltx:text[@framed='underline']">
    <underline>
      <xsl:apply-templates/>
    </underline>
  </xsl:template>

  <xsl:template match="ltx:rule">
    <hr/>
  </xsl:template>

  <xsl:template match="ltx:ERROR">
    An error in the conversion from LaTeX to XML has occurred here.
  </xsl:template>

  <xsl:template match="ltx:break"/>

</xsl:stylesheet>
