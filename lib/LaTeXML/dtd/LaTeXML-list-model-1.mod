<!--
 /=====================================================================\ 
 |  LaTeXML-list-model-1.mod                                           |
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

<!ELEMENT %LaTeXML.itemize.qname; (%LaTeXML.item.qname;)*>
<!ATTLIST %LaTeXML.itemize.qname; %LaTeXML.Common.attrib; %LaTeXML.ID.attrib;>

<!ELEMENT %LaTeXML.enumerate.qname; (%LaTeXML.item.qname;)*>
<!ATTLIST %LaTeXML.enumerate.qname; %LaTeXML.Common.attrib; %LaTeXML.ID.attrib;>

<!ELEMENT %LaTeXML.description.qname; (%LaTeXML.item.qname;)*>
<!ATTLIST %LaTeXML.description.qname; %LaTeXML.Common.attrib; %LaTeXML.ID.attrib;>

<!ELEMENT %LaTeXML.item.qname; (%LaTeXML.Block.mix; | %LaTeXML.tag.qname;)*>
<!ATTLIST %LaTeXML.item.qname; %LaTeXML.Common.attrib; %LaTeXML.Labelled.attrib;>

<!ELEMENT %LaTeXML.tag.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.tag.qname;
	  %LaTeXML.Common.attrib;
	  open  CDATA #IMPLIED
	  close CDATA #IMPLIED>

