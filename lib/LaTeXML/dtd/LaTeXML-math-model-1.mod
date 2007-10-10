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

<!ENTITY % LaTeXML.XMath.attrib	 "%LaTeXML-math.XMath.attrib;">
<!ENTITY % LaTeXML.Math.class	 "%LaTeXML-math.Math.class;">
<!ENTITY % LaTeXML.XMath.class	 "%LaTeXML-math.XMath.class;">

<!--% Outer container for all math. This holds the internal 
     <XMath> representation, as well as image data and other representations.-->
<!ELEMENT %LaTeXML.Math.qname; (%LaTeXML.Math.class;)*>
<!--% 
       @mode        display or inline mode.
       @tex         reconstruction of TeX that generated the math.
       @content-tex more semantic version of above.
       @text        a textified representation of the math.
-->
<!ATTLIST %LaTeXML.Math.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.Imageable.attrib;
          mode (display|inline) #IMPLIED
          tex    CDATA #IMPLIED
          content-tex    CDATA #IMPLIED
          text   CDATA #IMPLIED>

<!--% Internal representation of mathematics. -->
<!ELEMENT %LaTeXML.XMath.qname; (%LaTeXML.XMath.class;)*>
<!ATTLIST %LaTeXML.XMath.qname;
	  %LaTeXML.Common.attrib;
	  status CDATA #IMPLIED>

<!--% General mathematical token.-->
<!ELEMENT %LaTeXML.XMTok.qname; (#PCDATA)*>
<!--%
    @name  The name of the token, typically the control sequence that created it.
    @meaning A more semantic name corresponding to the intended meaning, such as the OpenMath name.
    @omcd    The OpenMath CD for which @meaning is a symbol.
    @style   Various random styling information. NOTE This needs to be made consistent.
    @font    The font, size a used for the symbol.
    @size,@color  The size and color for the symbol, not presumed to be meaningful(?)
    @scriptpos An encoding of the position of this token as a sub/superscript, used
            to handle aligned and nested scripts, both pre and post.
    @thickness ?
-->
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
	  scriptpos CDATA #IMPLIED
	  thickness CDATA #IMPLIED>

<!--% Generalized application of a function, operator, whatever (the first child)
     to arguments (the remaining children).  -->
<!ELEMENT %LaTeXML.XMApp.qname; (%LaTeXML.XMath.class;)*>
<!--% The attributes are a subset of those for <XMTok>. -->
<!ATTLIST %LaTeXML.XMApp.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          name      CDATA #IMPLIED
          meaning   CDATA #IMPLIED
	  scriptpos CDATA #IMPLIED>

<!--% Parallel markup of content (first child) and presentation (second child)
     of a mathematical object.
     Typically, the arguments are shared between the two branches:
     they appear in the content branch, with @ID's,
     and <XMRef> is used in the presentation branch -->
<!ELEMENT %LaTeXML.XMDual.qname; ((%LaTeXML.XMath.class;), (%LaTeXML.XMath.class;))>
<!ATTLIST %LaTeXML.XMDual.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;>


<!--% Various spacing items, generally ignored in parsing.-->
<!ELEMENT %LaTeXML.XMHint.qname; EMPTY>
<!--% The attributes are a subset of those for <XMTok>. -->
<!ATTLIST %LaTeXML.XMHint.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          name    CDATA #IMPLIED
          meaning CDATA #IMPLIED
          style   CDATA #IMPLIED>

<!--% Text appearing within math.-->
<!ELEMENT %LaTeXML.XMText.qname; (#PCDATA | %LaTeXML.Inline.class; %LaTeXML.Misc.class;)*>
<!ATTLIST %LaTeXML.XMText.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;>

<!--% Wrapper for a sequence of tokens used to assert the role of the
     contents in its parent. This element generally disappears after parsing.-->
<!ELEMENT %LaTeXML.XMWrap.qname; (%LaTeXML.XMath.class;)*>
<!--% The attributes are a subset of those for <XMTok>. -->
<!ATTLIST %LaTeXML.XMWrap.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          name    CDATA #IMPLIED
          meaning CDATA #IMPLIED
          style   CDATA #IMPLIED>

<!--% Wrapper for an argument to a structured macro.
     It implies that its content can be parsed independently of its parent,
     and thus generally disappears after parsing. -->
<!ELEMENT %LaTeXML.XMArg.qname; (%LaTeXML.XMath.class;)*>
<!ATTLIST %LaTeXML.XMArg.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          rule   CDATA #IMPLIED>

<!--% Structure sharing element typically used in the presentation
     branch of an <XMDual> to refer to the arguments present in the content branch. -->
<!ELEMENT %LaTeXML.XMRef.qname; EMPTY>
<!ATTLIST %LaTeXML.XMRef.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
	  %LaTeXML.IDREF.attrib;>

<!--% Math Array/Alignment structure. -->
<!ELEMENT %LaTeXML.XMArray.qname; (%LaTeXML.XMRow.qname;)*>
<!--% The attributes are a subset of those for <XMTok> or of <tabular>. -->
<!ATTLIST %LaTeXML.XMArray.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.XMath.attrib;
	  %LaTeXML.ID.attrib;
          name    CDATA #IMPLIED
          meaning CDATA #IMPLIED
          style   CDATA #IMPLIED
	  vattach (top|bottom) #IMPLIED
          width    CDATA #IMPLIED>

<!--% A row in a math alignment. -->
<!ELEMENT %LaTeXML.XMRow.qname; (%LaTeXML.XMCell.qname;)*>
<!ATTLIST %LaTeXML.XMRow.qname;
	  %LaTeXML.Common.attrib;>

<!--% A cell in a row of a math alignment.-->
<!ELEMENT %LaTeXML.XMCell.qname; (%LaTeXML.XMath.class;)*>
<!--% The attributes are the same as those for the <td> element. -->
<!ATTLIST %LaTeXML.XMCell.qname;
	  %LaTeXML.Common.attrib;
          rowpan  CDATA #IMPLIED
          colspan CDATA #IMPLIED
          align   CDATA #IMPLIED
          width   CDATA #IMPLIED
	  border  CDATA #IMPLIED
	  thead   (yes|no) #IMPLIED>
