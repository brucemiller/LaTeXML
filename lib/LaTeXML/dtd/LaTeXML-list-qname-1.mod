<!--
 /=====================================================================\ 
 |  LaTeXML-list-qname-1.mod                                           |
 | LaTeXML DTD Module for lists, enumerations, etc                     |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!ENTITY % LaTeXML.itemize.qname       "%LaTeXML.pfx;itemize">
<!ENTITY % LaTeXML.enumerate.qname     "%LaTeXML.pfx;enumerate">
<!ENTITY % LaTeXML.description.qname   "%LaTeXML.pfx;description">
<!ENTITY % LaTeXML.item.qname          "%LaTeXML.pfx;item">
<!ENTITY % LaTeXML.tag.qname           "%LaTeXML.pfx;tag">

<!ENTITY % LaTeXML-list.Block.class
	 "| %LaTeXML.itemize.qname; | %LaTeXML.enumerate.qname; | %LaTeXML.description.qname;">

