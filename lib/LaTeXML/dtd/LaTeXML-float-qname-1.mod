<!--
 /=====================================================================\ 
 |  LaTeXML-qname-1.dtd                                                |
 | LaTeXML DTD Module for floating elements                            |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!ENTITY % LaTeXML.figure.qname      "%LaTeXML.pfx;figure">
<!ENTITY % LaTeXML.table.qname       "%LaTeXML.pfx;table">
<!ENTITY % LaTeXML.caption.qname     "%LaTeXML.pfx;caption">
<!ENTITY % LaTeXML.toccaption.qname  "%LaTeXML.pfx;toccaption">


<!ENTITY % LaTeXML-float.Para.class
	 "| %LaTeXML.figure.qname; | %LaTeXML.table.qname;" >
<!ENTITY % LaTeXML-float.Caption.class
	 "%LaTeXML.caption.qname; | %LaTeXML.toccaption.qname;">
