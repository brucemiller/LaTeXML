<!--
 /=====================================================================\ 
 |  LaTeXML-graphics-model-1.mod                                       |
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


<!--% A graphical insertion of an external file.-->
<!ELEMENT %LaTeXML.graphics.qname; EMPTY>
<!--%
    @graphics the path to the graphics file
    @options an encoding of the scaling and positioning options
             to be used in processing the graphic.
-->
<!ATTLIST %LaTeXML.graphics.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.Imageable.attrib;
          graphic CDATA #REQUIRED
          options CDATA #IMPLIED>
