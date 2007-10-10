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

<!--% An alignment structure corresponding to tabular  or various similar forms.
     The model is basically a copy of HTML4's table.-->
<!ELEMENT %LaTeXML.tabular.qname;
          (((%LaTeXML.col.qname;)*|(%LaTeXML.colgroup.qname;)*),
           (%LaTeXML.thead.qname; | %LaTeXML.tfoot.qname; | %LaTeXML.tbody.qname;
             | %LaTeXML.tr.qname;)*)>
<!--%
    @vattach  which row's baseline aligns with the container's baseline.
    @width    the desired width of the tabular.
-->
<!ATTLIST %LaTeXML.tabular.qname;
	  %LaTeXML.Common.attrib; 
          vattach (top|middle|bottom) #IMPLIED
          width    CDATA #IMPLIED>

<!--
   NOTE: None of these are used(?)
    @pattern is the LaTeX tabular pattern used.
    @frame   whether the tabular should have an outer border.
    @rules   rules used.

<!ATTLIST %LaTeXML.tabular.qname;
	  %LaTeXML.Common.attrib; 
          pattern CDATA #IMPLIED
          frame   CDATA #IMPLIED
          rules   CDATA #IMPLIED>
-->

<!--% A container for descriptions of columns within the table.-->
<!ELEMENT %LaTeXML.colgroup.qname; (%LaTeXML.col.qname;)*>
<!--%
    @span the number of columns spanned by this column
    @align the default alignment of column content.
-->
<!ATTLIST %LaTeXML.colgroup.qname;
	  %LaTeXML.Common.attrib; 
          span  CDATA #IMPLIED
          align CDATA #IMPLIED>

<!--% A description of a column, but not the column data itself. -->
<!ELEMENT %LaTeXML.col.qname; EMPTY>
<!--%
    @span the number of columns spanned by this column
    @align the default alignment of column content.
-->
<!ATTLIST %LaTeXML.col.qname;
	  %LaTeXML.Common.attrib; 
          span  CDATA #IMPLIED
          align CDATA #IMPLIED>

<!--% A container for a set of rows that correspond to the header of the tabular.-->
<!ELEMENT %LaTeXML.thead.qname; (%LaTeXML.tr.qname;)*>
<!ATTLIST %LaTeXML.thead.qname; %LaTeXML.Common.attrib;>


<!--% A container for a set of rows that correspond to the footer of the tabular.-->
<!ELEMENT %LaTeXML.tfoot.qname; (%LaTeXML.tr.qname;)*>
<!ATTLIST %LaTeXML.tfoot.qname; %LaTeXML.Common.attrib;>

<!--% A container for a set of rows corresponding to the body of the tabular.-->
<!ELEMENT %LaTeXML.tbody.qname; (%LaTeXML.tr.qname;)*>
<!ATTLIST %LaTeXML.tbody.qname; %LaTeXML.Common.attrib;>

<!--% A row of a tabular.-->
<!ELEMENT %LaTeXML.tr.qname; (%LaTeXML.td.qname;)*>
<!ATTLIST %LaTeXML.tr.qname;
	  %LaTeXML.Common.attrib;
	  >

<!--% A cell in a row of a tabular.-->
<!ELEMENT %LaTeXML.td.qname; %LaTeXML.Flow.model;>
<!--%
     @colspan, @rowspan indicate how many columns or rows this cell spans or covers.
     @align should be left, right, center or justify.
     @width specifies the desired width for the column.
     @border records a sequence of t or tt, r or rr, b or bb and l or ll
             for borders or doubled borders on any side of the cell.
    @thead is yes if the cell corresponds to a table head or foot.
-->
<!ATTLIST %LaTeXML.td.qname;
	  %LaTeXML.Common.attrib; 
          colspan CDATA #IMPLIED
          rowspan CDATA #IMPLIED
          align   CDATA #IMPLIED
          width   CDATA #IMPLIED
	  border  CDATA #IMPLIED
	  thead   (yes|no) #IMPLIED
>
