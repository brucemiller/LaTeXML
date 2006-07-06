<!--
 /=====================================================================\ 
 |  LaTeXML-text-qname-1.mod                                           |
 | LaTeXML DTD Module for core inline text                             |
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

<!ENTITY % LaTeXML.text.qname      "%LaTeXML.pfx;text">
<!ENTITY % LaTeXML.emph.qname      "%LaTeXML.pfx;emph">
<!ENTITY % LaTeXML.vbox.qname      "%LaTeXML.pfx;vbox">
<!ENTITY % LaTeXML.rule.qname      "%LaTeXML.pfx;rule">


<!-- ======================================================================
     Meta Elements can appear anywhere -->

<!ENTITY % LaTeXML.note.qname           "%LaTeXML.pfx;note">
<!ENTITY % LaTeXML.ERROR.qname          "%LaTeXML.pfx;ERROR">

<!-- ======================================================================
     Inclusion -->

<!ENTITY % LaTeXML-text.Inline.class
	 "%LaTeXML.text.qname; | %LaTeXML.emph.qname;
	| %LaTeXML.vbox.qname;  | %LaTeXML.rule.qname;" >

<!ENTITY % LaTeXML-text.Meta.class
	 "| %LaTeXML.note.qname; | %LaTeXML.ERROR.qname;" >
