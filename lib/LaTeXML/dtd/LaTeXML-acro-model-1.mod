<!--
 /=====================================================================\ 
 |  LaTeXML-acro-model-1.mod                                           |
 | Modular DTD model for LaTeXML generated documents                   |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!-- This leverages module LaTeXML-list -->

<!ELEMENT %LaTeXML.acronym.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.acronym.qname;
	  %LaTeXML.Common.attrib; 
	  name CDATA #REQUIRED>

<!ELEMENT %LaTeXML.acronyms.qname; (%LaTeXML.item.qname;)*>
<!ATTLIST %LaTeXML.acronyms.qname; %LaTeXML.Common.attrib;>

