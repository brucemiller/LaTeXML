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

<!ELEMENT %LaTeXML.indexmark.qname; (%LaTeXML.indexphrase.qname;)*>
<!ATTLIST %LaTeXML.indexmark.qname; 
	  %LaTeXML.Common.attrib;
	  see_also CDATA #IMPLIED
	  style    CDATA #IMPLIED>

<!ELEMENT %LaTeXML.indexphrase.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.indexphrase.qname;
	  %LaTeXML.Common.attrib;
          key CDATA #IMPLIED>

<!ELEMENT %LaTeXML.indexlist.qname; (%LaTeXML.indexentry.qname;)*>
<!ATTLIST %LaTeXML.indexlist.qname;
	  %LaTeXML.Common.attrib;
	  id       ID #IMPLIED>

<!ELEMENT %LaTeXML.indexentry.qname; 
	  ((%LaTeXML.indexphrase.qname;), (%LaTeXML.indexrefs.qname;)?,
	   (%LaTeXML.indexlist.qname;)?)>
<!ATTLIST %LaTeXML.indexentry.qname;
	  %LaTeXML.Common.attrib;
	  id       ID #IMPLIED>
<!ELEMENT %LaTeXML.indexrefs.qname; %LaTeXML.Inline.model;>
