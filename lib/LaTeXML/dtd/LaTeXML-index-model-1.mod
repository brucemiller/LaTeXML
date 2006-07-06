<!--
 /=====================================================================\ 
 |  LaTeXML-index-model-1.mod                                          |
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

<!ELEMENT %LaTeXML.index.qname; (%LaTeXML.indexphrase.qname;)*>
<!ATTLIST %LaTeXML.index.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML.indexphrase.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.indexphrase.qname; %LaTeXML.Common.attrib;>
