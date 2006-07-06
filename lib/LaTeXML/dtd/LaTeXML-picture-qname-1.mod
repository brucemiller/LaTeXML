<!--
 /=====================================================================\ 
 |  LaTeXML-picture-qname-1.dtd                                        |
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
     Picture; 
     This is still somewhat experimental;
     it is roughly a simple subset of SVG? -->

<!ENTITY % LaTeXML.picture.qname "%LaTeXML.pfx;picture">
<!ENTITY % LaTeXML.g.qname       "%LaTeXML.pfx;g">
<!ENTITY % LaTeXML.rect.qname    "%LaTeXML.pfx;rect">
<!ENTITY % LaTeXML.line.qname    "%LaTeXML.pfx;line">
<!ENTITY % LaTeXML.polygon.qname "%LaTeXML.pfx;polygon">
<!ENTITY % LaTeXML.wedge.qname   "%LaTeXML.pfx;wedge">
<!ENTITY % LaTeXML.arc.qname     "%LaTeXML.pfx;arc">
<!ENTITY % LaTeXML.circle.qname  "%LaTeXML.pfx;circle">
<!ENTITY % LaTeXML.ellipse.qname "%LaTeXML.pfx;ellipse">
<!ENTITY % LaTeXML.path.qname    "%LaTeXML.pfx;path">
<!ENTITY % LaTeXML.bezier.qname  "%LaTeXML.pfx;bezier">

<!ENTITY % LaTeXML-picture.Misc.class
	 "| %LaTeXML.picture.qname;">

<!ENTITY % LaTeXML-picture.Picture.class
         "%LaTeXML.g.qname; | %LaTeXML.rect.qname; | %LaTeXML.line.qname;
          | %LaTeXML.circle.qname; | %LaTeXML.path.qname; | %LaTeXML.arc.qname;
	  | %LaTeXML.wedge.qname; | %LaTeXML.ellipse.qname; | %LaTeXML.polygon.qname;
	  | %LaTeXML.bezier.qname;">

<!ENTITY % LaTeXML-picture.Picture.attrib
	 "x CDATA #IMPLIED
	  y CDATA #IMPLIED
	  r CDATA #IMPLIED
          rx CDATA #IMPLIED
	  ry CDATA #IMPLIED 
          width CDATA #IMPLIED
	  height CDATA #IMPLIED
          fill CDATA #IMPLIED
	  stroke CDATA #IMPLIED 
          stroke-width CDATA #IMPLIED
	  stroke-dasharray CDATA #IMPLIED
          transform CDATA #IMPLIED
	  terminators CDATA #IMPLIED
	  arrowlength CDATA #IMPLIED
          points CDATA #IMPLIED
	  showpoints CDATA #IMPLIED
	  displayedpoints CDATA #IMPLIED
	  arc CDATA #IMPLIED 
          angle1 CDATA #IMPLIED
	  angle2 CDATA #IMPLIED 
          arcsepA CDATA #IMPLIED
	  arcsepB CDATA #IMPLIED
          curvature CDATA #IMPLIED">

<!ENTITY % LaTeXML-picture.PictureGroup.attrib
	  "pos CDATA #IMPLIED
	   framed (yes|no) 'no'
           frametype (rect|circle|oval) 'rect'
           fillframe (yes|no) 'no'
           boxsep CDATA #IMPLIED
           shadowbox (yes|no) 'no'
           doubleline (yes|no) 'no'">
