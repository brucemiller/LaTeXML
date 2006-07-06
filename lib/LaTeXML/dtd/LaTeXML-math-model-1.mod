<!--
 /=====================================================================\ 
 |  LaTeXML-math-model-1.mod                                           |
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
     Math -->

<!-- If no driver has assembled these so far: -->
<!ENTITY % LaTeXML.XMath.attrib	 "%LaTeXML-math.XMath.attrib;">
<!ENTITY % LaTeXML.Math.class	 "%LaTeXML-math.Math.class;">
<!ENTITY % LaTeXML.XMath.class	 "%LaTeXML-math.XMath.class;">

<!-- CLEANUP: Should we have an XMText element, instead of reusing text?
     The parser tends to want to add math-specific attributes even to text. -->


<!ELEMENT %LaTeXML.Math.qname; (%LaTeXML.Math.class;)*>
<!ATTLIST %LaTeXML.Math.qname;
	  %LaTeXML.Common.attrib;
          mode (display|inline) #IMPLIED
          tex    CDATA #IMPLIED
          content-tex    CDATA #IMPLIED
          text   CDATA #IMPLIED
          mathimage CDATA #IMPLIED
          width  CDATA #IMPLIED
          height CDATA #IMPLIED>

<!ELEMENT %LaTeXML.XMath.qname; (%LaTeXML.XMath.class;)*>
<!ATTLIST %LaTeXML.XMath.qname;
	  %LaTeXML.Common.attrib;
	  status CDATA #IMPLIED>

<!ELEMENT %LaTeXML.XMApp.qname; (%LaTeXML.XMath.class;)*>
<!ATTLIST %LaTeXML.XMApp.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          name         CDATA #IMPLIED
          meaning CDATA #IMPLIED
	  stackscripts CDATA #IMPLIED>

<!ELEMENT %LaTeXML.XMDual.qname; ((%LaTeXML.XMath.class;), (%LaTeXML.XMath.class;))>
<!ATTLIST %LaTeXML.XMDual.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;>

<!ELEMENT %LaTeXML.XMTok.qname; (#PCDATA)*>
<!ATTLIST %LaTeXML.XMTok.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          name    CDATA #IMPLIED
          meaning CDATA #IMPLIED
	  omcd    CDATA #IMPLIED
          style   CDATA #IMPLIED
          font    CDATA #IMPLIED
          size    CDATA #IMPLIED
          color   CDATA #IMPLIED
	  stackscripts CDATA #IMPLIED
	  thickness  CDATA #IMPLIED
	  possibleFunction CDATA #IMPLIED>
<!-- and alignment  ?? -->

<!ELEMENT %LaTeXML.XMHint.qname; EMPTY>
<!ATTLIST %LaTeXML.XMHint.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          name    CDATA #IMPLIED
          meaning CDATA #IMPLIED
          style   CDATA #IMPLIED>

<!ELEMENT %LaTeXML.XMText.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.XMText.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;>

<!ELEMENT %LaTeXML.XMWrap.qname; (%LaTeXML.XMath.class;)*>
<!ATTLIST %LaTeXML.XMWrap.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          name    CDATA #IMPLIED
          meaning CDATA #IMPLIED
          style   CDATA #IMPLIED>

<!ELEMENT %LaTeXML.XMArg.qname; (%LaTeXML.XMath.class;)*>
<!ATTLIST %LaTeXML.XMArg.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          rule   CDATA #IMPLIED>

<!ELEMENT %LaTeXML.XMRef.qname; EMPTY>
<!ATTLIST %LaTeXML.XMRef.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
	  %LaTeXML.IDREF.attrib;>

<!ELEMENT %LaTeXML.XMArray.qname; (%LaTeXML.XMRow.qname;)*>
<!ATTLIST %LaTeXML.XMArray.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          name    CDATA #IMPLIED
          meaning CDATA #IMPLIED>

<!ELEMENT %LaTeXML.XMRow.qname; (%LaTeXML.XMCell.qname;)*>
<!ATTLIST %LaTeXML.XMRow.qname;
	  %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML.XMCell.qname; (%LaTeXML.XMath.class;)*>
<!ATTLIST %LaTeXML.XMCell.qname;
	  %LaTeXML.Common.attrib;
          rowpan  CDATA #IMPLIED
          colspan CDATA #IMPLIED
          align   CDATA #IMPLIED
          width   CDATA #IMPLIED
	  border  CDATA #IMPLIED
	  thead   (yes|no) #IMPLIED>
