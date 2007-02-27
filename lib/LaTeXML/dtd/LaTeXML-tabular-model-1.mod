<!--
 /=====================================================================\ 
 |  LaTeXML-tabular-model-1.dtd                                        |
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
<!-- tabular is basically cribbed from HTML4's table -->
<!ELEMENT %LaTeXML.tabular.qname;
          (((%LaTeXML.col.qname;)*|(%LaTeXML.colgroup.qname;)*),
           (%LaTeXML.thead.qname; | %LaTeXML.tfoot.qname; | %LaTeXML.tbody.qname; | %LaTeXML.tr.qname;)*)>
<!ATTLIST %LaTeXML.tabular.qname;
	  %LaTeXML.Common.attrib; 
          pattern CDATA #IMPLIED
          frame   CDATA #IMPLIED
          rules   CDATA #IMPLIED>

<!ELEMENT %LaTeXML.colgroup.qname; (%LaTeXML.col.qname;)*>
<!ATTLIST %LaTeXML.colgroup.qname;
	  %LaTeXML.Common.attrib; 
          span  CDATA #IMPLIED
          align CDATA #IMPLIED>

<!ATTLIST %LaTeXML.col.qname;
	  %LaTeXML.Common.attrib; 
          span  CDATA #IMPLIED
          align CDATA #IMPLIED>

<!ELEMENT %LaTeXML.thead.qname; (%LaTeXML.tr.qname;)*>
<!ATTLIST %LaTeXML.thead.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML.tfoot.qname; (%LaTeXML.tr.qname;)*>
<!ATTLIST %LaTeXML.tfoot.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML.tbody.qname; (%LaTeXML.tr.qname;)*>
<!ATTLIST %LaTeXML.tbody.qname; %LaTeXML.Common.attrib;>

<!ELEMENT %LaTeXML.tr.qname; (%LaTeXML.td.qname; | %LaTeXML.td-between.qname;)*>
<!ATTLIST %LaTeXML.tr.qname;
	  %LaTeXML.Common.attrib;
	  >

<!ELEMENT %LaTeXML.td.qname; %LaTeXML.Flow.model;>
<!ATTLIST %LaTeXML.td.qname;
	  %LaTeXML.Common.attrib; 
          colspan CDATA #IMPLIED
          rowspan CDATA #IMPLIED
          align   CDATA #IMPLIED
          width   CDATA #IMPLIED
	  border  CDATA #IMPLIED
	  thead   (yes|no) #IMPLIED
>
<!ELEMENT %LaTeXML.td-between.qname; %LaTeXML.Flow.model;>
