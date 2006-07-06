<!--
 /=====================================================================\ 
 |  LaTeXML-core-1.mod                                                 |
 | Core declarations for LaTeXML Modular DTD                           |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!ENTITY % NS.prefixed "IGNORE">
<!ENTITY % LaTeXML.prefixed "%NS.prefixed;">
<!ENTITY % LaTeXML.xmlns "http://dlmf.nist.gov/LaTeXML">
<!ENTITY % LaTeXML.prefix "ltxml">

<![%LaTeXML.prefixed;[
<!ENTITY % LaTeXML.pfx "%LaTeXML.prefix;:">
<!ENTITY % LaTeXML.xmlns.extra.attrib
  	 "xmlns:%LaTeXML.prefix; CDATA #FIXED '%LaTeXML.xmlns;'">
]]>
<!ENTITY % LaTeXML.pfx "">
<!ENTITY % LaTeXML.xmlns.extra.attrib "">


<!-- ======================================================================
     Parameterized attributes -->
<!ENTITY % LaTeXML.Common.attrib.base
	 "xmlns CDATA #IMPLIED">
<!ENTITY % LaTeXML.Common.attrib.extra "">
<!ENTITY % LaTeXML.Common.attrib
	 "%LaTeXML.Common.attrib.base; %LaTeXML.Common.attrib.extra; %LaTeXML.xmlns.extra.attrib;">

<!-- ======================================================================
     Document structure -->
<!ENTITY % LaTeXML.ID.attrib.base
	 "id     ID    #IMPLIED">
<!ENTITY % LaTeXML.ID.attrib.extra "">
<!ENTITY % LaTeXML.ID.attrib "
         %LaTeXML.ID.attrib.base; %LaTeXML.ID.attrib.extra;">

<!ENTITY % LaTeXML.IDREF.attrib.base
	 "idref  IDREF #IMPLIED">
<!ENTITY % LaTeXML.IDREF.attrib.extra "">
<!ENTITY % LaTeXML.IDREF.attrib "
         %LaTeXML.IDREF.attrib.base; %LaTeXML.IDREF.attrib.extra;">

<!ENTITY % LaTeXML.Labelled.attrib.base
	 "label  CDATA #IMPLIED
          refnum CDATA #IMPLIED">
<!ENTITY % LaTeXML.Labelled.attrib.extra "">
<!ENTITY % LaTeXML.Labelled.attrib "
         %LaTeXML.ID.attrib.base; %LaTeXML.ID.attrib.extra;
         %LaTeXML.Labelled.attrib.base; %LaTeXML.Labelled.attrib.extra;">
