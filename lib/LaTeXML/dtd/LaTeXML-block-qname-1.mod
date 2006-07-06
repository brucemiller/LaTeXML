<!--
 /=====================================================================\ 
 |  LaTeXML-block-qname-1.mod                                          |
 | LaTeXML DTD Module: basic block elements                            |
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
     contained within logical paragraphs -->

<!ENTITY % LaTeXML.p.qname             "%LaTeXML.pfx;p">
<!ENTITY % LaTeXML.equation.qname      "%LaTeXML.pfx;equation">
<!ENTITY % LaTeXML.equationgroup.qname "%LaTeXML.pfx;equationgroup">
<!ENTITY % LaTeXML.verbatim.qname      "%LaTeXML.pfx;verbatim">
<!ENTITY % LaTeXML.centering.qname     "%LaTeXML.pfx;centering">

<!-- ======================================================================
     Para Elements: Logical Paragraphs -->

<!ENTITY % LaTeXML.para.qname   "%LaTeXML.pfx;para">

<!-- ======================================================================
     Misc Elements
     can appear in block or inline contexts. -->

<!ENTITY % LaTeXML.quote.qname          "%LaTeXML.pfx;quote">
<!ENTITY % LaTeXML.minipage.qname       "%LaTeXML.pfx;minipage">

<!-- ======================================================================
     Declare contributions to various classes. -->
<!ENTITY % LaTeXML-block.Block.class
	 "%LaTeXML.p.qname; | %LaTeXML.equation.qname;  | %LaTeXML.equationgroup.qname;
	| %LaTeXML.quote.qname; | %LaTeXML.centering.qname;" >
<!ENTITY % LaTeXML-block.Misc.class
	 "| %LaTeXML.minipage.qname; | %LaTeXML.verbatim.qname;">
<!ENTITY % LaTeXML-block.Para.class
	 "%LaTeXML.para.qname;">
