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
          labelref CDATA #IMPLIED>

<!ELEMENT %LaTeXML.cite.qname; ((%LaTeXML.citepre.qname;)?, (%LaTeXML.citepost.qname;)?)>
<!ATTLIST %LaTeXML.cite.qname;
	  %LaTeXML.Common.attrib; 
          ref CDATA #IMPLIED
          style (intext|parenthetic) #IMPLIED
          show CDATA #IMPLIED>

<!ELEMENT %LaTeXML.citepre.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.citepre.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML.citepost.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.citepost.qname; %LaTeXML.Common.attrib;>
     
<!ELEMENT %LaTeXML.a.qname;  %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.a.qname;
	  %LaTeXML.Common.attrib; 
          href CDATA #REQUIRED>
