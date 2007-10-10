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

<!--% General container for styled text. -->
<!ELEMENT %LaTeXML.text.qname; %LaTeXML.Inline.model;>
<!--% Attributes cover a variety of styling and position shifting properties. -->
<!ATTLIST %LaTeXML.text.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.Positionable.attrib;
          font       CDATA #IMPLIED
          size       CDATA #IMPLIED
          color      CDATA #IMPLIED
	  framed    (square|rectangle|circle|underline) #IMPLIED>

<!--% Emphasized text. -->
<!ELEMENT %LaTeXML.emph.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.emph.qname; %LaTeXML.Common.attrib;>

<!--% A Rule.-->
<!ELEMENT %LaTeXML.rule.qname; EMPTY>
<!ATTLIST %LaTeXML.rule.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.Positionable.attrib;>

<!-- ======================================================================
     Meta data -->

<!--% Metadata that covers several `out of band' annotations.-->
<!ELEMENT %LaTeXML.note.qname;  %LaTeXML.Flow.model;>
<!--%
     @mark indicates the desired visible marker to be linked to the note. -->
<!ATTLIST %LaTeXML.note.qname;
	  %LaTeXML.Common.attrib; 
          mark CDATA #IMPLIED>
<!-- should mark be more like label/refnum ? -->

<!--% error object for undefined control sequences, or whatever -->
<!ELEMENT %LaTeXML.ERROR.qname; (#PCDATA)*>
<!ATTLIST %LaTeXML.ERROR.qname; %LaTeXML.Common.attrib;>
