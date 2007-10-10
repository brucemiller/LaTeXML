<!--
 /=====================================================================\ 
 |  LaTeXML-xref-qname-1.mod                                           |
 | LaTeXML DTD Module for cross-references                             |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!ENTITY % LaTeXML.ref.qname       "%LaTeXML.pfx;ref">
<!ENTITY % LaTeXML.cite.qname      "%LaTeXML.pfx;cite">
<!ENTITY % LaTeXML.bibref.qname    "%LaTeXML.pfx;bibref">
<!ENTITY % LaTeXML.anchor.qname    "%LaTeXML.pfx;anchor">

<!ENTITY % LaTeXML-xref.Inline.class 
	 "| %LaTeXML.anchor.qname; | %LaTeXML.ref.qname;
          | %LaTeXML.cite.qname; | %LaTeXML.bibref.qname;">
