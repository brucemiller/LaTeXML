<!--
 /=====================================================================\ 
 |  LaTeXML-theorem-model-1.dtd                                        |
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

<!ELEMENT %LaTeXML.theorem.qname;
          ((%LaTeXML.title.qname;)?,
	  (%LaTeXML.Block.mix;)*)>

<!ATTLIST %LaTeXML.theorem.qname;
	  %LaTeXML.Common.attrib; 
          %LaTeXML.Labelled.attrib;>

<!ELEMENT %LaTeXML.proof.qname;
          ((%LaTeXML.title.qname;)?,
	  (%LaTeXML.Block.mix;)*)>

<!ATTLIST %LaTeXML.proof.qname;
	  %LaTeXML.Common.attrib;>
