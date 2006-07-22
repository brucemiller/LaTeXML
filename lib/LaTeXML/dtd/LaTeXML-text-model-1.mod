<!--
 /=====================================================================\ 
 |  LaTeXML-text-model-1.mod                                           |
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

<!-- ======================================================================
     Inline Elements -->

<!ELEMENT %LaTeXML.text.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.text.qname;
	  %LaTeXML.Common.attrib;
          font    CDATA #IMPLIED
          size    CDATA #IMPLIED
          color   CDATA #IMPLIED
	  framed (square|rectangle|circle|underline) #IMPLIED
	  width   CDATA #IMPLIED
	  height  CDATA #IMPLIED
	  pad-width CDATA #IMPLIED
	  raise   CDATA #IMPLIED
	  shift   CDATA #IMPLIED
	  class   CDATA #IMPLIED>

<!ELEMENT %LaTeXML.emph.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.emph.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML.vbox.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.vbox.qname;
	  %LaTeXML.Common.attrib; 
	  height CDATA #IMPLIED
	  pad-height CDATA #IMPLIED
	  align  (left|center|right) #IMPLIED
	  valign (top|middle|bottom) #IMPLIED>

<!ELEMENT %LaTeXML.rule.qname; EMPTY>
<!ATTLIST %LaTeXML.rule.qname;
	  %LaTeXML.Common.attrib;
	  width CDATA #IMPLIED
	  height CDATA #IMPLIED
	  raise CDATA #IMPLIED
	  depth CDATA #IMPLIED>

<!-- ======================================================================
     Meta data -->

<!-- note covers several `out of band' annotations.
     class could be foot, end, margin or other extensions. -->
<!ELEMENT %LaTeXML.note.qname;  %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.note.qname;
	  %LaTeXML.Common.attrib; 
	  class CDATA #IMPLIED
          mark CDATA #IMPLIED>
<!-- should mark be more like label/refnum ? -->

<!-- error object for undefined control sequences, or whatever -->
<!ELEMENT %LaTeXML.ERROR.qname; (#PCDATA)*>
<!ATTLIST %LaTeXML.ERROR.qname;
	  type CDATA #IMPLIED>
