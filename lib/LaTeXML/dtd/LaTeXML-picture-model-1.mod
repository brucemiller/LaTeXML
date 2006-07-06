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


<!ELEMENT %LaTeXML.picture.qname;  (%LaTeXML.Picture.class;)*>
<!ATTLIST %LaTeXML.picture.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.Picture.attrib; 
          clip (yes|no) 'no'
          baseline CDATA #IMPLIED 
          tex CDATA #IMPLIED>

<!ELEMENT %LaTeXML.g.qname;       (%LaTeXML.Picture.class;)*>
<!ATTLIST %LaTeXML.g.qname;       %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib; %LaTeXML.PictureGroup.attrib; >

<!ELEMENT %LaTeXML.rect.qname;    EMPTY>
<!ATTLIST %LaTeXML.rect.qname;    %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!ELEMENT %LaTeXML.line.qname;    EMPTY>
<!ATTLIST %LaTeXML.line.qname;    %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!ELEMENT %LaTeXML.polygon.qname; EMPTY>
<!ATTLIST %LaTeXML.polygon.qname; %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!ELEMENT %LaTeXML.wedge.qname;   EMPTY>
<!ATTLIST %LaTeXML.wedge.qname;   %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!ELEMENT %LaTeXML.arc.qname;     EMPTY>
<!ATTLIST %LaTeXML.arc.qname;     %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!ELEMENT %LaTeXML.circle.qname;  EMPTY>
<!ATTLIST %LaTeXML.circle.qname;  %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!ELEMENT %LaTeXML.ellipse.qname; EMPTY>
<!ATTLIST %LaTeXML.ellipse.qname; %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!ELEMENT %LaTeXML.path.qname;    EMPTY>
<!ATTLIST %LaTeXML.path.qname;    %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>

<!ELEMENT %LaTeXML.bezier.qname;  EMPTY>
<!ATTLIST %LaTeXML.bezier.qname;  %LaTeXML.Common.attrib; %LaTeXML.Picture.attrib;>
