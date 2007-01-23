<!--
 /=====================================================================\ 
 |  LaTeXML-block-model-1.mod                                          |
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
     Block Elements
     ====================================================================== -->

<!ELEMENT %LaTeXML.p.qname; 
	  (#PCDATA | %LaTeXML.Inline.mix; | %LaTeXML.break.qname;)*>
<!ATTLIST %LaTeXML.p.qname; %LaTeXML.Common.attrib;>

<!-- with some trepidation, allow captions here too -->
<!ELEMENT %LaTeXML.centering.qname; (%LaTeXML.caption.qname; | %LaTeXML.toccaption.qname; | %LaTeXML.Block.mix;)*>
<!ATTLIST %LaTeXML.centering.qname; %LaTeXML.Common.attrib;>

<!-- Equation's model is just Inline which includes Math, the main expected ingredient.
     But, other things can end up in display math, too, so we use Inline. -->
<!ELEMENT %LaTeXML.equation.qname; 
	  (#PCDATA | %LaTeXML.Inline.mix; %LaTeXML-extra.Equation.class;)*>
<!ATTLIST %LaTeXML.equation.qname;
	  %LaTeXML.Common.attrib; %LaTeXML.Labelled.attrib;>

<!ELEMENT %LaTeXML.equationgroup.qname;
	  (%LaTeXML.Block.mix;  %LaTeXML-extra.Equation.class;)*>
<!ATTLIST %LaTeXML.equationgroup.qname;
	  %LaTeXML.Common.attrib; %LaTeXML.Labelled.attrib;>

<!ELEMENT %LaTeXML.quote.qname;
	  (#PCDATA | %LaTeXML.Inline.mix; | %LaTeXML.break.qname;)*>

<!ATTLIST %LaTeXML.quote.qname; %LaTeXML.Common.attrib;>

<!-- generic block (fallback) -->
<!ELEMENT %LaTeXML.block.qname; 
	  (#PCDATA | %LaTeXML.Inline.mix; | %LaTeXML.break.qname;)*>
<!ATTLIST %LaTeXML.block.qname;
	  %LaTeXML.Common.attrib;
	  class CDATA #IMPLIED>

<!ELEMENT %LaTeXML.break.qname; EMPTY>

<!-- ======================================================================
     Misc Elements
     can appear in Flow contexts ( block or inline, but within logical paragraphs)
     ====================================================================== -->

<!ELEMENT %LaTeXML.minipage.qname; (%LaTeXML.Para.mix;)*>
<!ATTLIST %LaTeXML.minipage.qname;
	  %LaTeXML.Common.attrib;
	  pos CDATA #IMPLIED
	  width CDATA #IMPLIED
	  justified CDATA #IMPLIED>

<!ELEMENT %LaTeXML.verbatim.qname;
	  (#PCDATA | %LaTeXML.Inline.mix; | %LaTeXML.break.qname;)*>
<!ATTLIST %LaTeXML.verbatim.qname;
	  %LaTeXML.Common.attrib; 
	  font CDATA #IMPLIED>

<!-- ======================================================================
     Para Elements
     ====================================================================== -->

<!ELEMENT %LaTeXML.para.qname; (%LaTeXML.Block.mix;)*>
<!-- Also allow id on para -->
<!ATTLIST %LaTeXML.para.qname; %LaTeXML.Common.attrib; %LaTeXML.ID.attrib;>

<!ELEMENT %LaTeXML.quotation.qname; (%LaTeXML.Block.mix;)*>
<!ATTLIST %LaTeXML.quotation.qname; %LaTeXML.Common.attrib;>



