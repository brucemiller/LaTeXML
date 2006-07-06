<!--
 /=====================================================================\ 
 |  LaTeXML-math-qname-1.mod                                           |
 | LaTeXML DTD Module for the math                                     |
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
     <Math> is inline unless contained within an equation or similar. -->

<!ENTITY % LaTeXML.Math.qname   "%LaTeXML.pfx;Math">
<!ENTITY % LaTeXML.XMath.qname  "%LaTeXML.pfx;XMath">
<!ENTITY % LaTeXML.XMApp.qname  "%LaTeXML.pfx;XMApp">
<!ENTITY % LaTeXML.XMDual.qname "%LaTeXML.pfx;XMDual">
<!ENTITY % LaTeXML.XMTok.qname  "%LaTeXML.pfx;XMTok">
<!ENTITY % LaTeXML.XMHint.qname "%LaTeXML.pfx;XMHint">
<!ENTITY % LaTeXML.XMWrap.qname "%LaTeXML.pfx;XMWrap">
<!ENTITY % LaTeXML.XMArg.qname  "%LaTeXML.pfx;XMArg">
<!ENTITY % LaTeXML.XMRef.qname  "%LaTeXML.pfx;XMRef">
<!ENTITY % LaTeXML.XMText.qname "%LaTeXML.pfx;XMText">
<!ENTITY % LaTeXML.XMArray.qname "%LaTeXML.pfx;XMArray">
<!ENTITY % LaTeXML.XMRow.qname   "%LaTeXML.pfx;XMRow">
<!ENTITY % LaTeXML.XMCell.qname  "%LaTeXML.pfx;XMCell">

<!ENTITY % LaTeXML-math.Inline.class "| %LaTeXML.Math.qname;">

<!-- Extensibility:
     Alternative math representations can be added via %LaTeXML-extra.Math.class;
     -->
<!ENTITY % LaTeXML-math.Math.class
	 "%LaTeXML.XMath.qname;">

<!--
<!ENTITY % LaTeXML-math.XMath.class
        "%LaTeXML.XMApp.qname; | %LaTeXML.XMTok.qname; | %LaTeXML.XMRef.qname;
       | %LaTeXML.XMHint.qname; | %LaTeXML.XMArg.qname; | %LaTeXML.XMWrap.qname;
       | %LaTeXML.XMDual.qname; | %LaTeXML.text.qname;">
-->
<!ENTITY % LaTeXML-math.XMath.class
        "%LaTeXML.XMApp.qname; | %LaTeXML.XMTok.qname; | %LaTeXML.XMRef.qname;
       | %LaTeXML.XMHint.qname; | %LaTeXML.XMArg.qname; | %LaTeXML.XMWrap.qname;
       | %LaTeXML.XMDual.qname; | %LaTeXML.XMText.qname;
       | %LaTeXML.XMArray.qname;">

<!ENTITY % LaTeXML-math.XMath.attrib "
         role    CDATA #IMPLIED
	 open    CDATA #IMPLIED
	 close   CDATA #IMPLIED
	 punctuation  CDATA #IMPLIED
	 argopen CDATA #IMPLIED
	 argclose CDATA #IMPLIED
	 separators CDATA #IMPLIED">
<!-- open, close can end up on most/all elements ? -->



