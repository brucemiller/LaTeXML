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

<!--% An itemized list.-->
<!ELEMENT %LaTeXML.itemize.qname; (%LaTeXML.item.qname;)*>
<!ATTLIST %LaTeXML.itemize.qname; %LaTeXML.Common.attrib; %LaTeXML.ID.attrib;>

<!--% An enumerated list.-->
<!ELEMENT %LaTeXML.enumerate.qname; (%LaTeXML.item.qname;)*>
<!ATTLIST %LaTeXML.enumerate.qname; %LaTeXML.Common.attrib; %LaTeXML.ID.attrib;>

<!--% A description list. The <item>s within are expected to have a <tag>
     which represents the term being described in each <item>.-->
<!ELEMENT %LaTeXML.description.qname; (%LaTeXML.item.qname;)*>
<!ATTLIST %LaTeXML.description.qname; %LaTeXML.Common.attrib; %LaTeXML.ID.attrib;>

<!--% An item within a list.-->
<!ELEMENT %LaTeXML.item.qname; (%LaTeXML.Block.mix; | %LaTeXML.tag.qname;)*>
<!ATTLIST %LaTeXML.item.qname; %LaTeXML.Common.attrib; %LaTeXML.Labelled.attrib;>

<!--% A tag within an item indicating the term or bullet for a given item.-->
<!ELEMENT %LaTeXML.tag.qname; %LaTeXML.Inline.model;>
<!--% 
    @open,@close opening and closing delimiters used to display the tag.
-->
<!ATTLIST %LaTeXML.tag.qname;
	  %LaTeXML.Common.attrib;
	  open  CDATA #IMPLIED
	  close CDATA #IMPLIED>

