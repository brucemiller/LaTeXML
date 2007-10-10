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

<!--% A physical paragraph. -->
<!ELEMENT %LaTeXML.p.qname; 
	  (#PCDATA | %LaTeXML.Inline.mix; | %LaTeXML.break.qname;)*>
<!ATTLIST %LaTeXML.p.qname; %LaTeXML.Common.attrib;>

<!--% A physical block that centers its content.-->
<!ELEMENT %LaTeXML.centering.qname; (%LaTeXML.caption.qname; | %LaTeXML.toccaption.qname; | %LaTeXML.Block.mix;)*>
<!ATTLIST %LaTeXML.centering.qname; %LaTeXML.Common.attrib;>

<!--% An Equation.  The model is just Inline which includes <Math>, the main expected ingredient.
     However, other things can end up in display math, too, so we use Inline. -->
<!ELEMENT %LaTeXML.equation.qname; 
	  (#PCDATA | %LaTeXML.Inline.mix; %LaTeXML-extra.Equation.class;)*>
<!ATTLIST %LaTeXML.equation.qname;
	  %LaTeXML.Common.attrib; %LaTeXML.Labelled.attrib;>

<!--% A group of equations, perhaps aligned (Though this is nowhere recorded).-->
<!ELEMENT %LaTeXML.equationgroup.qname;
	  (%LaTeXML.Block.mix;  %LaTeXML-extra.Equation.class;)*>
<!ATTLIST %LaTeXML.equationgroup.qname;
	  %LaTeXML.Common.attrib; %LaTeXML.Labelled.attrib;>

<!--% A quotation-->
<!ELEMENT %LaTeXML.quote.qname;
	  (#PCDATA | %LaTeXML.Inline.mix; | %LaTeXML.break.qname;)*>
<!ATTLIST %LaTeXML.quote.qname; %LaTeXML.Common.attrib;>

<!--% A generic block (fallback). -->
<!ELEMENT %LaTeXML.block.qname; 
	  (#PCDATA | %LaTeXML.Inline.mix; | %LaTeXML.break.qname;)*>
<!ATTLIST %LaTeXML.block.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.Positionable.attrib;>

<!--% A forced line break.-->
<!ELEMENT %LaTeXML.break.qname; EMPTY>

<!-- ======================================================================
     Misc Elements
     can appear in Flow contexts ( block or inline, but within logical paragraphs)
     ====================================================================== -->

<!--% An inline block. Actually, can appear in inline or block mode, but
      typesets its contents as a block.  -->
<!ELEMENT %LaTeXML.inline-block.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.inline-block.qname;
	  %LaTeXML.Common.attrib; 
	  %LaTeXML.Positionable.attrib;>

<!--% Verbatim content-->
<!ELEMENT %LaTeXML.verbatim.qname;
	  (#PCDATA | %LaTeXML.Inline.mix; | %LaTeXML.break.qname;)*>
<!ATTLIST %LaTeXML.verbatim.qname;
	  %LaTeXML.Common.attrib; 
	  font CDATA #IMPLIED>

<!-- ======================================================================
     Para Elements
     ====================================================================== -->

<!--% A Logical paragraph. It has an @ID, but not a @label. -->
<!ELEMENT %LaTeXML.para.qname; (%LaTeXML.Block.mix;)*>
<!ATTLIST %LaTeXML.para.qname; %LaTeXML.Common.attrib; %LaTeXML.ID.attrib;>




