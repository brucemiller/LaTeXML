<!--
 /=====================================================================\ 
 |  LaTeXML-xref-model-1.mod                                           |
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

<!ELEMENT %LaTeXML.ref.qname;  %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.ref.qname;
	  %LaTeXML.Common.attrib; 
	  %LaTeXML.IDREF.attrib; 
          labelref CDATA #IMPLIED
          show     CDATA #IMPLIED
	  href     CDATA #IMPLIED
	  title    CDATA #IMPLIED>

<!ELEMENT %LaTeXML.cite.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.cite.qname;
	  %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML.bibref.qname;  %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.bibref.qname;
	  %LaTeXML.Common.attrib; 
	  %LaTeXML.IDREF.attrib; 
          bibrefs  CDATA #IMPLIED
          show     CDATA #IMPLIED>
