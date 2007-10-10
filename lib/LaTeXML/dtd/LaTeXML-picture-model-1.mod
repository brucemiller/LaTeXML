<!--
 /=====================================================================\ 
 |  LaTeXML-picture-model-1.dtd                                        |
 | LaTeXML DTD Module for picture & pstricks environments              |
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
     Picture; Experimental, possibly should evolve to SVG?
     ====================================================================== -->

<!-- If no driver has assembled these so far: -->
<!ENTITY % LaTeXML.Picture.class        "%LaTeXML-picture.Picture.class;">
<!ENTITY % LaTeXML.Picture.attrib       "%LaTeXML-picture.Picture.attrib;">
<!ENTITY % LaTeXML.PictureGroup.attrib  "%LaTeXML-picture.PictureGroup.attrib;">


<!--% A picture environment.-->
<!ELEMENT %LaTeXML.picture.qname;  (%LaTeXML.Picture.class;)*>
<!ATTLIST %LaTeXML.picture.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.Picture.attrib; 
	  %LaTeXML.Imageable.attrib; 
          clip (yes|no) 'no'
          baseline CDATA #IMPLIED 
	  unitlength CDATA #IMPLIED
	  xunitlength CDATA #IMPLIED
	  yunitlength CDATA #IMPLIED
          tex CDATA #IMPLIED
	  content-tex CDATA #IMPLIED>

<!--% A graphical grouping; the content is inherits by the transformations, 
     positioning and other properties.-->
<!ELEMENT %LaTeXML.g.qname;       (%LaTeXML.Picture.class;)*>
<!ATTLIST %LaTeXML.g.qname;    
	  %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib; %LaTeXML.PictureGroup.attrib; >

<!--% A rectangle within a <picture>.-->
<!ELEMENT %LaTeXML.rect.qname;    EMPTY>
<!ATTLIST %LaTeXML.rect.qname;    %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!--% A line within a <picture>.-->
<!ELEMENT %LaTeXML.line.qname;    EMPTY>
<!ATTLIST %LaTeXML.line.qname;    %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!--% A polygon within a <picture>.-->
<!ELEMENT %LaTeXML.polygon.qname; EMPTY>
<!ATTLIST %LaTeXML.polygon.qname; %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!--% A wedge within a <picture>.-->
<!ELEMENT %LaTeXML.wedge.qname;   EMPTY>
<!ATTLIST %LaTeXML.wedge.qname;   %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!--% An arc within a <picture>.-->
<!ELEMENT %LaTeXML.arc.qname;     EMPTY>
<!ATTLIST %LaTeXML.arc.qname;     %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!--% A circle within a <picture>.-->
<!ELEMENT %LaTeXML.circle.qname;  EMPTY>
<!ATTLIST %LaTeXML.circle.qname;  %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!--% An ellipse within a <picture>.-->
<!ELEMENT %LaTeXML.ellipse.qname; EMPTY>
<!ATTLIST %LaTeXML.ellipse.qname; %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!--% A path within a <picture>.-->
<!ELEMENT %LaTeXML.path.qname;    EMPTY>
<!ATTLIST %LaTeXML.path.qname;    %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!--% A bezier curve within a <picture>.-->
<!ELEMENT %LaTeXML.bezier.qname;  EMPTY>
<!ATTLIST %LaTeXML.bezier.qname;  %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>
