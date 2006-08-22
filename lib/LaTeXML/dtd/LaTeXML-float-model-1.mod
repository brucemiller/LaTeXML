<!--
 /=====================================================================\ 
 |  LaTeXML-float-model-1.mod                                          |
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

<!-- If no driver has assembled these so far: -->
<!ENTITY % LaTeXML.Caption.class "%LaTeXML-float.Caption.class;">

<!ELEMENT %LaTeXML.figure.qname;
	  (%LaTeXML.Block.mix; | %LaTeXML.Caption.class; %LaTeXML-extra.Figure.class;)*>
<!ATTLIST %LaTeXML.figure.qname;
	  %LaTeXML.Common.attrib; 
          %LaTeXML.Labelled.attrib;
          placement CDATA #IMPLIED>

<!ELEMENT %LaTeXML.table.qname;
	  (%LaTeXML.Block.mix; | %LaTeXML.Caption.class; %LaTeXML-extra.Table.class;)*>
<!ATTLIST %LaTeXML.table.qname;
	  %LaTeXML.Common.attrib; 
	  %LaTeXML.Labelled.attrib;
          placement CDATA #IMPLIED>

<!ELEMENT %LaTeXML.caption.qname;     %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.caption.qname;     %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML.toccaption.qname;  %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.toccaption.qname;  %LaTeXML.Common.attrib;>

