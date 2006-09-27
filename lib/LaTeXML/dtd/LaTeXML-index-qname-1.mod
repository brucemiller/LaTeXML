<!--
 /=====================================================================\ 
 |  LaTeXML-index-qname-1.mod                                          |
 | LaTeXML DTD Module for indexing                                     |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!-- Elements for marking keywords in the document -->
<!ENTITY % LaTeXML.indexmark.qname      "%LaTeXML.pfx;indexmark">
<!ENTITY % LaTeXML.indexphrase.qname    "%LaTeXML.pfx;indexphrase">

<!-- Elements for marking up the index itself -->
<!ENTITY % LaTeXML.indexlist.qname       "%LaTeXML.pfx;indexlist">
<!ENTITY % LaTeXML.indexentry.qname      "%LaTeXML.pfx;indexentry">
<!ENTITY % LaTeXML.indexrefs.qname       "%LaTeXML.pfx;indexrefs">

<!ENTITY % LaTeXML-index.Meta.class
	 "| %LaTeXML.indexmark.qname;">
