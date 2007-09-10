<!--
 /=====================================================================\ 
 |  LaTeXML-qname-1.dtd                                                |
 | Modular DTD qnames for LaTeXML generated documents                  |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!-- ======================================================================
     Document Structure -->

<!ENTITY % LaTeXML.document.qname       "%LaTeXML.pfx;document">
<!ENTITY % LaTeXML.book.qname           "%LaTeXML.pfx;book">
<!ENTITY % LaTeXML.part.qname           "%LaTeXML.pfx;part">
<!ENTITY % LaTeXML.chapter.qname        "%LaTeXML.pfx;chapter">
<!ENTITY % LaTeXML.section.qname        "%LaTeXML.pfx;section">
<!ENTITY % LaTeXML.subsection.qname     "%LaTeXML.pfx;subsection">
<!ENTITY % LaTeXML.subsubsection.qname  "%LaTeXML.pfx;subsubsection">
<!ENTITY % LaTeXML.paragraph.qname      "%LaTeXML.pfx;paragraph">
<!ENTITY % LaTeXML.subparagraph.qname   "%LaTeXML.pfx;subparagraph">
<!ENTITY % LaTeXML.bibliography.qname   "%LaTeXML.pfx;bibliography">
<!ENTITY % LaTeXML.index.qname          "%LaTeXML.pfx;index">

<!ENTITY % LaTeXML.appendix.qname       "%LaTeXML.pfx;appendix">

<!ENTITY % LaTeXML.title.qname          "%LaTeXML.pfx;title">
<!ENTITY % LaTeXML.toctitle.qname       "%LaTeXML.pfx;toctitle">
<!ENTITY % LaTeXML.subtitle.qname       "%LaTeXML.pfx;subtitle">
<!ENTITY % LaTeXML.creator.qname        "%LaTeXML.pfx;creator">
<!ENTITY % LaTeXML.personname.qname     "%LaTeXML.pfx;personname">
<!ENTITY % LaTeXML.contact.qname        "%LaTeXML.pfx;contact">
<!ENTITY % LaTeXML.date.qname           "%LaTeXML.pfx;date">
<!ENTITY % LaTeXML.abstract.qname       "%LaTeXML.pfx;abstract">
<!ENTITY % LaTeXML.acknowledgements.qname "%LaTeXML.pfx;acknowledgements">
<!ENTITY % LaTeXML.keywords.qname       "%LaTeXML.pfx;keywords">
<!ENTITY % LaTeXML.classification.qname "%LaTeXML.pfx;classfication">


<!ENTITY % LaTeXML-structure.Person.class
	 "%LaTeXML.personname.qname; | %LaTeXML.contact.qname;">
<!ENTITY % LaTeXML-structure.SectionalFrontMatter.class
	 "%LaTeXML.title.qname; | %LaTeXML.toctitle.qname; | %LaTeXML.creator.qname;">
<!ENTITY % LaTeXML-structure.FrontMatter.class
         "%LaTeXML.subtitle.qname; | %LaTeXML.date.qname; | %LaTeXML.abstract.qname;
        | %LaTeXML.acknowledgements.qname; | %LaTeXML.keywords.qname;
	| %LaTeXML.classification.qname;">
<!ENTITY % LaTeXML-structure.BackMatter.class
	 "%LaTeXML.bibliography.qname; | %LaTeXML.appendix.qname; | %LaTeXML.index.qname;">
