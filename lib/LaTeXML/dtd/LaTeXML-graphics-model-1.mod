<!--
 /=====================================================================\ 
 |  LaTeXML-graphics-model-1.mod                                       |
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


<!ELEMENT %LaTeXML.graphics.qname; EMPTY>
<!ATTLIST %LaTeXML.graphics.qname;
	  %LaTeXML.Common.attrib; 
          graphic CDATA #REQUIRED
          options CDATA #IMPLIED
          src     CDATA #IMPLIED
          width   CDATA #IMPLIED
          height  CDATA #IMPLIED>
<!-- last 3 not used directly in latexml -->
