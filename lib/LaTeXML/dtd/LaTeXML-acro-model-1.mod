<!--
 /=====================================================================\ 
 |  LaTeXML-acro-model-1.mod                                           |
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

<!-- This leverages module LaTeXML-list -->

<!--% Represents an acronym. -->
<!ELEMENT %LaTeXML.acronym.qname; %LaTeXML.Inline.model;>
<!--%
   @name attribute should be used to indicate the expansion of the acronym.
-->
<!ATTLIST %LaTeXML.acronym.qname;
	  %LaTeXML.Common.attrib; 
	  name CDATA #REQUIRED>

<!--% An acronyms list similar to a description.  The <tag> within an <item>
     would typically be the acronym, with the text of the <item> providing
     a description of it.-->
<!ELEMENT %LaTeXML.acronyms.qname; (%LaTeXML.item.qname;)*>
<!ATTLIST %LaTeXML.acronyms.qname; %LaTeXML.Common.attrib;>

