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

<!--% This module defines the parameter entities and core attribute sets
    used by most other modules. -->


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

<!--% Attributes shared by ALL elements.
    @xmlns provides for namespace declaration.
    @class can be used to add differentiate different instances of elements
           without introducing new element declarations; 
	   it generally shouldn't be used for deep semantic distinctions, however.
	   This attribute is carried over to HTML and can be used for CSS selection.
-->
<!ENTITY % LaTeXML.Common.attrib
	 "%LaTeXML.Common.attrib.base; %LaTeXML.Common.attrib.extra; %LaTeXML.xmlns.extra.attrib;">

<!-- ======================================================================
     Document structure -->

<!ENTITY % LaTeXML.ID.attrib.base
	 "id     ID    #IMPLIED">
<!ENTITY % LaTeXML.ID.attrib.extra "">

<!--% Attributes for elements that can be cross-referenced
     from inside or outside the document.
     @id  the unique identifier of the element, 
          usually generated automatically by the latexml.
 -->
<!ENTITY % LaTeXML.ID.attrib "
         %LaTeXML.ID.attrib.base; %LaTeXML.ID.attrib.extra;">

<!ENTITY % LaTeXML.IDREF.attrib.base
	 "idref  IDREF #IMPLIED">
<!ENTITY % LaTeXML.IDREF.attrib.extra "">


<!--% Attributes for elements that can cross-reference other elements.
      @idref the identifier of the referred-to element.
-->
<!ENTITY % LaTeXML.IDREF.attrib "
         %LaTeXML.IDREF.attrib.base; %LaTeXML.IDREF.attrib.extra;">

<!ENTITY % LaTeXML.Labelled.attrib.base
	 "label  CDATA #IMPLIED
          refnum CDATA #IMPLIED">
<!ENTITY % LaTeXML.Labelled.attrib.extra "">

<!--% Attributes for elements that can be labelled from within LaTeX.
    @label the LaTeX label of the element, supplied by the \label macro.
    @refnum the reference number (ie. section number, equation number, etc)
           of the object.
 -->
<!ENTITY % LaTeXML.Labelled.attrib "
         %LaTeXML.ID.attrib.base; %LaTeXML.ID.attrib.extra;
         %LaTeXML.Labelled.attrib.base; %LaTeXML.Labelled.attrib.extra;">

<!--% Attributes shared by low-level, generic inline and block elements
    that can be sized or shifted.
    @width,@height,@depth the size of the box.
    @pad-width,@pad-height extra size beyond its natural size.
    @xoffset,@yoffset shifts the position of the box.
    @align alignment of material within the box.
    @vattach specifies which line of the box is aligned to the
             baseline of the containing object.
-->
<!ENTITY % LaTeXML.Positionable.attrib.base
	 "width      CDATA #IMPLIED
	  height     CDATA #IMPLIED
	  depth      CDATA #IMPLIED
	  pad-width  CDATA #IMPLIED
	  pad-height CDATA #IMPLIED
	  xoffset    CDATA #IMPLIED
	  yoffset    CDATA #IMPLIED
	  align      (left|center|right|justified) #IMPLIED
	  vattach    (top|middle|bottom) #IMPLIED">
<!ENTITY % LaTeXML.Positionable.attrib.extra "">

<!ENTITY % LaTeXML.Positionable.attrib
	 "%LaTeXML.Positionable.attrib.base; %LaTeXML.Positionable.attrib.extra;">

<!--% Attributes for elements that may be converted to image form
    during postprocessing, such as math, graphics, pictures, etc.
    @imagesrc the file, possibly generated from other data.
    @imagewidth the width in pixels of @imagesrc.
    @imageheight the height in pixels of @imagesrc.
-->
<!ENTITY % LaTeXML.Imageable.attrib.base
	 "imagesrc    CDATA #IMPLIED
	  imagewidth  CDATA #IMPLIED
	  imageheight CDATA #IMPLIED">
<!ENTITY % LaTeXML.Imageable.attrib.extra "">
<!ENTITY % LaTeXML.Imageable.attrib
	 "%LaTeXML.Imageable.attrib.base; %LaTeXML.Imageable.attrib.extra;">
