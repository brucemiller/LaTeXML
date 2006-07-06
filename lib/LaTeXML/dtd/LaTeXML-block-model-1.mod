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

<!ELEMENT %LaTeXML.p.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.p.qname; %LaTeXML.Common.attrib;>

<!-- with some trepidation, allow captions here too -->
<!ELEMENT %LaTeXML.centering.qname; (%LaTeXML.caption.qname; | %LaTeXML.toccaption.qname; | %LaTeXML.Block.mix;)*>
<!ATTLIST %LaTeXML.centering.qname; %LaTeXML.Common.attrib;>

<!-- Equation's model is just Inline which includes Math, the main expected ingredient.
     But, other things can end up in display math, too, so we use Inline. -->
<!ELEMENT %LaTeXML.equation.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.equation.qname;  %LaTeXML.Common.attrib; %LaTeXML.Labelled.attrib;>

<!ELEMENT %LaTeXML.equationgroup.qname; (%LaTeXML.Block.mix;)*>
<!ATTLIST %LaTeXML.equationgroup.qname; %LaTeXML.Common.attrib; %LaTeXML.Labelled.attrib;>

<!ELEMENT %LaTeXML.quote.qname;  %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.quote.qname; %LaTeXML.Common.attrib;>


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

<!ELEMENT %LaTeXML.verbatim.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.verbatim.qname;
	  %LaTeXML.Common.attrib; 
	  font CDATA #IMPLIED>

<!-- ======================================================================
     Para Elements
     ====================================================================== -->

<!ELEMENT %LaTeXML.para.qname; (%LaTeXML.Block.mix;)*>
<!-- Also allow id on para -->
<!ATTLIST %LaTeXML.para.qname; %LaTeXML.Common.attrib; %LaTeXML.ID.attrib;>



