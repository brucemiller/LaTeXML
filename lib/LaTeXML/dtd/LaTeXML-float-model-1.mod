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


<!--% A  figure, possibly captioned.-->
<!ELEMENT %LaTeXML.figure.qname;
	  (%LaTeXML.Block.mix; | %LaTeXML.Caption.class; %LaTeXML-extra.Figure.class;)*>
<!--
     @placement the floating placement parameter that determines where the object is displayed.
-->
<!ATTLIST %LaTeXML.figure.qname;
	  %LaTeXML.Common.attrib; 
          %LaTeXML.Labelled.attrib;
          placement CDATA #IMPLIED>

<!--% A  Table, possibly captioned. This is not necessarily a <tabular>.-->
<!ELEMENT %LaTeXML.table.qname;
	  (%LaTeXML.Block.mix; | %LaTeXML.Caption.class; %LaTeXML-extra.Table.class;)*>
<!--
     @placement the floating placement parameter that determines where the object is displayed.
-->
<!ATTLIST %LaTeXML.table.qname;
	  %LaTeXML.Common.attrib; 
	  %LaTeXML.Labelled.attrib;
          placement CDATA #IMPLIED>

<!--% A caption for a <table> or <figure>.-->
<!ELEMENT %LaTeXML.caption.qname;     %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.caption.qname;     %LaTeXML.Common.attrib;>

<!--% A short form of <table> or <figure> caption, used for lists of figures or similar.-->
<!ELEMENT %LaTeXML.toccaption.qname;  %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.toccaption.qname;  %LaTeXML.Common.attrib;>

