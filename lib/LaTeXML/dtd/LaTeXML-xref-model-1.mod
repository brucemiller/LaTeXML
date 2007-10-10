<!--
 /=====================================================================\ 
 |  LaTeXML-xref-model-1.mod                                           |
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

<!--% A hyperlink reference to some other object. 
     When converted to HTML, the content would be the content of the anchor.
-->
<!ELEMENT %LaTeXML.ref.qname;  %LaTeXML.Inline.model;>
<!--% The destination can be specified by one of the 
     attributes @labelref, @idref or @href;
     Missing fields will usually be filled in during postprocessing,
     based on data extracted from the document(s).

     @labelref for a LaTeX labelled object,
     @idref    for an internal identifier, or
     @href     for an arbitrary url.
     @title    attribute gives a longer form description of the target,
               this would typically appear as a tooltip in HTML.
-->
<!ATTLIST %LaTeXML.ref.qname;
	  %LaTeXML.Common.attrib; 
	  %LaTeXML.IDREF.attrib; 
          labelref CDATA #IMPLIED
          show     CDATA #IMPLIED
	  href     CDATA #IMPLIED
	  title    CDATA #IMPLIED>

<!--% Inline anchor.-->
<!ELEMENT %LaTeXML.anchor.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.anchor.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.ID.attrib;>

<!--% A container for a bibliographic citation. The model is inline to
     allow arbitrary comments before and after the expected <bibref>(s)
     which are the specific citation.-->
<!ELEMENT %LaTeXML.cite.qname; %LaTeXML.Inline.model;>
<!ATTLIST %LaTeXML.cite.qname;
	  %LaTeXML.Common.attrib;>

<!--% A bibliographic citation refering to a specific bibliographic item.-->
<!ELEMENT %LaTeXML.bibref.qname;  %LaTeXML.Inline.model;>
<!--% 
   @bibrefs a comma separated list of bibligraphic keys.
   @show encodes which of author(s), year, title, etc will
         be displayed. NOTE: Describe this.
 -->
<!ATTLIST %LaTeXML.bibref.qname;
	  %LaTeXML.Common.attrib; 
	  %LaTeXML.IDREF.attrib; 
          bibrefs  CDATA #IMPLIED
          show     CDATA #IMPLIED>
