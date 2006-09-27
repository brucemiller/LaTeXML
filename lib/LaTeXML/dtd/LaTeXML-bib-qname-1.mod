<!--
 /=====================================================================\ 
 |  LaTeXML-bib-qname-1.mod                                            |
 | LaTeXML DTD Module for BibTeX                                       |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!-- CLEANUP: Initially these elements start with "bib-" to avoid conflicts.
     Now that namespaces are more possible, consider using a separate namespace.
-->

<!ENTITY % NS.prefixed "IGNORE">
<!ENTITY % LaTeXML-bib.prefixed "%NS.prefixed;">
<!ENTITY % LaTeXML-bib.xmlns "http://dlmf.nist.gov/LaTeXML/">
<!ENTITY % LaTeXML-bib.prefix "ltxml">

<![%LaTeXML-bib.prefixed;[
<!ENTITY % LaTeXML-bib.pfx "%LaTeXML.prefix;"">
<!ENTITY % LaTeXML-bib.xmlns.extra.attrib
  	 "xmlns:%LaTeXML-bib.prefix; CDATA #FIXED '%LaTeXML-bib.xmlns;'">
]]>
<!ENTITY % LaTeXML-bib.pfx "">
<!ENTITY % LaTeXML-bib.xmlns.extra.attrib "">

<!-- ======================================================================
     Bibliography
     ====================================================================== -->

<!ENTITY % LaTeXML-bib.biblist.qname        "%LaTeXML-bib.pfx;biblist">
<!ENTITY % LaTeXML-bib.bibentry.qname       "%LaTeXML-bib.pfx;bibentry">
<!ENTITY % LaTeXML-bib.bib-author.qname     "%LaTeXML-bib.pfx;bib-author">
<!ENTITY % LaTeXML-bib.bib-editor.qname     "%LaTeXML-bib.pfx;bib-editor">
<!ENTITY % LaTeXML-bib.bib-translator.qname "%LaTeXML-bib.pfx;bib-translator">
<!ENTITY % LaTeXML-bib.surname.qname        "%LaTeXML-bib.pfx;surname">
<!ENTITY % LaTeXML-bib.givenname.qname      "%LaTeXML-bib.pfx;givenname">
<!ENTITY % LaTeXML-bib.initials.qname       "%LaTeXML-bib.pfx;initials">
<!ENTITY % LaTeXML-bib.lineage.qname        "%LaTeXML-bib.pfx;lineage">
<!ENTITY % LaTeXML-bib.bib-title.qname      "%LaTeXML-bib.pfx;bib-title">
<!ENTITY % LaTeXML-bib.bib-subtitle.qname   "%LaTeXML-bib.pfx;bib-subtitle">
<!ENTITY % LaTeXML-bib.bib-booktitle.qname  "%LaTeXML-bib.pfx;bib-booktitle">
<!ENTITY % LaTeXML-bib.bib-key.qname        "%LaTeXML-bib.pfx;bib-key">
<!ENTITY % LaTeXML-bib.bib-journal.qname    "%LaTeXML-bib.pfx;bib-journal">
<!ENTITY % LaTeXML-bib.bib-series.qname     "%LaTeXML-bib.pfx;bib-series">
<!ENTITY % LaTeXML-bib.bib-conference.qname "%LaTeXML-bib.pfx;bib-conference">
<!ENTITY % LaTeXML-bib.bib-publisher.qname  "%LaTeXML-bib.pfx;bib-publisher">
<!ENTITY % LaTeXML-bib.bib-organization.qname "%LaTeXML-bib.pfx;bib-organization">
<!ENTITY % LaTeXML-bib.bib-institution.qname "%LaTeXML-bib.pfx;bib-institution">
<!ENTITY % LaTeXML-bib.bib-address.qname    "%LaTeXML-bib.pfx;bib-address">
<!ENTITY % LaTeXML-bib.bib-volume.qname     "%LaTeXML-bib.pfx;bib-volume">
<!ENTITY % LaTeXML-bib.bib-number.qname     "%LaTeXML-bib.pfx;bib-number">
<!ENTITY % LaTeXML-bib.bib-pages.qname      "%LaTeXML-bib.pfx;bib-pages">
<!ENTITY % LaTeXML-bib.bib-part.qname       "%LaTeXML-bib.pfx;bib-part">
<!ENTITY % LaTeXML-bib.bib-date.qname       "%LaTeXML-bib.pfx;bib-date">
<!ENTITY % LaTeXML-bib.bib-edition.qname    "%LaTeXML-bib.pfx;bib-edition">
<!ENTITY % LaTeXML-bib.bib-status.qname     "%LaTeXML-bib.pfx;bib-status">
<!ENTITY % LaTeXML-bib.bib-type.qname       "%LaTeXML-bib.pfx;bib-type">
<!ENTITY % LaTeXML-bib.bib-issn.qname       "%LaTeXML-bib.pfx;bib-issn">
<!ENTITY % LaTeXML-bib.bib-isbn.qname       "%LaTeXML-bib.pfx;bib-isbn">
<!ENTITY % LaTeXML-bib.bib-doi.qname        "%LaTeXML-bib.pfx;bib-doi">
<!ENTITY % LaTeXML-bib.bib-review.qname     "%LaTeXML-bib.pfx;bib-review">
<!ENTITY % LaTeXML-bib.bib-mr.qname         "%LaTeXML-bib.pfx;bib-mr">
<!ENTITY % LaTeXML-bib.bib-mrnumber.qname   "%LaTeXML-bib.pfx;bib-mrnumber">
<!ENTITY % LaTeXML-bib.bib-mrreviewer.qname "%LaTeXML-bib.pfx;bib-mrreviewer">
<!ENTITY % LaTeXML-bib.bib-language.qname   "%LaTeXML-bib.pfx;bib-language">
<!ENTITY % LaTeXML-bib.bib-url.qname        "%LaTeXML-bib.pfx;bib-url">
<!ENTITY % LaTeXML-bib.bib-eprint.qname     "%LaTeXML-bib.pfx;bib-eprint">
<!ENTITY % LaTeXML-bib.bib-preprint.qname   "%LaTeXML-bib.pfx;bib-preprint">
<!ENTITY % LaTeXML-bib.bib-note.qname       "%LaTeXML-bib.pfx;bib-note">
<!ENTITY % LaTeXML-bib.bibitem.qname        "%LaTeXML-bib.pfx;bibitem">
<!ENTITY % LaTeXML-bib.bibblock.qname       "%LaTeXML-bib.pfx;bibblock">


<!-- The content model of the bibliographic bibentry; all fields that can be contained -->
<!ENTITY % LaTeXML-bib.Bibentry.class
	 "%LaTeXML-bib.bib-author.qname; | %LaTeXML-bib.bib-editor.qname; | %LaTeXML-bib.bib-translator.qname;
	  | %LaTeXML-bib.bib-title.qname; | %LaTeXML-bib.bib-subtitle.qname; | %LaTeXML-bib.bib-booktitle.qname;
          | %LaTeXML-bib.bib-key.qname;
	  | %LaTeXML-bib.bib-journal.qname; | %LaTeXML-bib.bib-series.qname; | %LaTeXML-bib.bib-conference.qname;
          | %LaTeXML-bib.bib-publisher.qname;  | %LaTeXML-bib.bib-organization.qname; | %LaTeXML-bib.bib-institution.qname;
          | %LaTeXML-bib.bib-address.qname;
          | %LaTeXML-bib.bib-volume.qname; | %LaTeXML-bib.bib-number.qname; | %LaTeXML-bib.bib-pages.qname;
          | %LaTeXML-bib.bib-part.qname; | %LaTeXML-bib.bib-date.qname; | %LaTeXML-bib.bib-edition.qname; 
	  | %LaTeXML-bib.bib-status.qname; | %LaTeXML-bib.bib-type.qname; 
	  | %LaTeXML-bib.bib-issn.qname; | %LaTeXML-bib.bib-doi.qname; | %LaTeXML-bib.bib-isbn.qname;
          | %LaTeXML-bib.bib-review.qname; | %LaTeXML-bib.bib-mrnumber.qname; | %LaTeXML-bib.bib-mrreviewer.qname; 
	  | %LaTeXML-bib.bib-language.qname; | %LaTeXML-bib.bib-url.qname;
          | %LaTeXML-bib.bib-eprint.qname; | %LaTeXML-bib.bib-preprint.qname; | %LaTeXML-bib.bib-note.qname;">

<!-- The content model of the bibliographic name fields (author, editor, translator)-->
<!ENTITY % LaTeXML-bib.Bibname.model
         "(%LaTeXML-bib.surname.qname;,
	  (%LaTeXML-bib.givenname.qname;)?,
	   (%LaTeXML-bib.initials.qname;)?,
	    (%LaTeXML-bib.lineage.qname;)?)">
