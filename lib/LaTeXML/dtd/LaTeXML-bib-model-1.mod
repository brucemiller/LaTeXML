<!--
 /=====================================================================\ 
 |  LaTeXML-bib-model-1.mod                                            |
 | Modular DTD model for LaTeXML bibtex module                         |
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
     Bibliography
     ====================================================================== -->

<!-- Would be nice to use somebody elses already-developed DTD... -->
<!-- Some notes:
     There're two classes of things here:
     bibentry : which would be the translation of a .bib file
     bibitem  : which would be the formatted items in a latex bibliography environment.
     	        This latter has typically lost much information during formatting.
  -->

<!-- If no driver has assembled these so far: -->
<!ENTITY % LaTeXML.Bibentry.class "%LaTeXML-bib.Bibentry.class;">
<!ENTITY % LaTeXML.Bibname.model  "%LaTeXML-bib.Bibname.model;">


<!ELEMENT %LaTeXML-bib.biblist.qname; (%LaTeXML-bib.bibentry.qname; | %LaTeXML-bib.bibitem.qname;)*>
<!ATTLIST %LaTeXML-bib.biblist.qname; %LaTeXML.Common.attrib;>
   
<!-- Semantic bibliography model; would result from parsing BibTeX -->
<!ELEMENT %LaTeXML-bib.bibentry.qname; (%LaTeXML.Bibentry.class;)*>
<!ATTLIST %LaTeXML-bib.bibentry.qname;
	  %LaTeXML.Common.attrib; 
          key CDATA #REQUIRED
          type CDATA #REQUIRED>

<!-- ======================================================================
     Bibliographic fields in a bibentry.
     ====================================================================== -->

<!ELEMENT %LaTeXML-bib.bib-author.qname; %LaTeXML.Bibname.model;>
<!ATTLIST %LaTeXML-bib.bib-author.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-editor.qname; %LaTeXML.Bibname.model;>
<!ATTLIST %LaTeXML-bib.bib-editor.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-translator.qname; %LaTeXML.Bibname.model;>
<!ATTLIST %LaTeXML-bib.bib-translator.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.surname.qname;   %LaTeXML.Inline.model;>
<!ELEMENT %LaTeXML-bib.givenname.qname; %LaTeXML.Inline.model;>
<!ELEMENT %LaTeXML-bib.initials.qname;  %LaTeXML.Inline.model;>
<!ELEMENT %LaTeXML-bib.lineage.qname;   %LaTeXML.Inline.model;>

<!ELEMENT %LaTeXML-bib.bib-title.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-title.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-subtitle.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-subtitle.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-booktitle.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-booktitle.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-key.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-key.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-journal.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-journal.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-series.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-series.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-conference.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-conference.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-publisher.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-publisher.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-organization.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-organization.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-institution.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-institution.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-address.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-address.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-volume.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-volume.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-number.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-number.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-pages.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-pages.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-part.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-part.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-date.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-date.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-edition.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-edition.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-status.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-status.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-type.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-type.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-issn.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-issn.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-isbn.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-isbn.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-doi.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-doi.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-review.qname;
	  (#PCDATA | %LaTeXML.Inline.mix; | %LaTeXML-bib.bib-mr.qname;)*>
<!ATTLIST %LaTeXML-bib.bib-review.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-mr.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-mr.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-mrnumber.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-mrnumber.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-mrreviewer.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-mrreviewer.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-language.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-language.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-url.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-url.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-eprint.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-eprint.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-preprint.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-preprint.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML-bib.bib-note.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML-bib.bib-note.qname; %LaTeXML.Common.attrib;>

<!-- ======================================================================
     bibitem is the formatted, presentation, form, typically information has been lost;
     it basically contains a biblabel and several bibblock's
     ====================================================================== -->

<!ELEMENT %LaTeXML-bib.bibitem.qname; ((%LaTeXML-bib.biblabel.qname;)?, (%LaTeXML-bib.bibblock.qname;)*)>
<!ATTLIST %LaTeXML-bib.bibitem.qname; %LaTeXML.Common.attrib;
		   key ID #REQUIRED>
<!ELEMENT %LaTeXML-bib.biblabel.qname; %LaTeXML.Inline.model;>
<!ELEMENT %LaTeXML-bib.bibblock.qname; %LaTeXML.Inline.model;>
 
